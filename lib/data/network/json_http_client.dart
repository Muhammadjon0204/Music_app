import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/core/utils/cancellation.dart';

/// GET requests returning JSON, with the failure handling every provider
/// needs: a hard [timeout] (the request is aborted, not just abandoned),
/// cancellation, typed failures per HTTP status, JSON validation, and at
/// most [maxAttempts] tries for transient failures (timeouts, 502–504).
/// Never retries 4xx or rate limits, so it cannot cause a request storm.
///
/// Logs show only host and path: queries can contain search text or keys.
final class JsonHttpClient {
  JsonHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 600),
    this.maxResponseBytes = 4 * 1024 * 1024,
    this._logger,
  }) : assert(maxAttempts >= 1),
       _client = client ?? http.Client();

  final Duration timeout;
  final int maxAttempts;

  /// Wait before a retry, multiplied by the attempt number.
  final Duration retryDelay;

  /// Larger bodies are rejected as invalid (a catalog page is far smaller).
  final int maxResponseBytes;

  final http.Client _client;
  final AppLogger? _logger;

  Future<Result<Object?>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
    Cancellation? cancellation,
  }) async {
    for (var attempt = 1; ; attempt++) {
      if (cancellation?.isCancelled ?? false) {
        return const Err(CancelledFailure());
      }
      final result = await _attempt(uri, headers, cancellation);
      if (result case Err(:final failure)
          when attempt < maxAttempts && _isTransient(failure)) {
        _logger?.info('GET ${_redacted(uri)} retry after $failure');
        await _wait(retryDelay * attempt, cancellation);
        continue;
      }
      return result;
    }
  }

  /// Releases connections. The client cannot be used afterwards.
  void close() => _client.close();

  Future<Result<Object?>> _attempt(
    Uri uri,
    Map<String, String> headers,
    Cancellation? cancellation,
  ) async {
    // One trigger aborts the request on cancellation or on timeout, so a
    // slow server does not keep a connection open in the background.
    final abort = Completer<void>();
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    unawaited(
      cancellation?.whenCancelled.then((_) {
        if (!abort.isCompleted) abort.complete();
      }),
    );

    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    )..headers.addAll({'Accept': 'application/json', ...headers});
    final started = DateTime.now();
    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final result = _decode(uri, response);
      _logger?.debug(
        'GET ${_redacted(uri)} → ${response.statusCode} '
        'in ${DateTime.now().difference(started).inMilliseconds} ms',
      );
      return result;
    } on http.RequestAbortedException catch (e, stackTrace) {
      if (timedOut) {
        _logger?.warning('GET ${_redacted(uri)} timed out');
        return Err(
          TimeoutFailure(
            debugMessage: 'No answer within $timeout',
            cause: e,
            stackTrace: stackTrace,
          ),
        );
      }
      return const Err(CancelledFailure());
    } on http.ClientException catch (e, stackTrace) {
      // Raised on all platforms for DNS, connection and TLS failures.
      if (cancellation?.isCancelled ?? false) {
        return const Err(CancelledFailure());
      }
      _logger?.warning('GET ${_redacted(uri)} network error: ${e.message}');
      return Err(
        NetworkFailure(
          debugMessage: e.message,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Result<Object?> _decode(Uri uri, http.Response response) {
    final status = response.statusCode;
    final where = _redacted(uri);
    if (status >= 200 && status < 300) {
      if (response.bodyBytes.length > maxResponseBytes) {
        return Err(
          InvalidResponseFailure(
            debugMessage: '$where: ${response.bodyBytes.length} bytes',
          ),
        );
      }
      try {
        return Ok(jsonDecode(utf8.decode(response.bodyBytes)));
      } on FormatException catch (e, stackTrace) {
        return Err(
          InvalidResponseFailure(
            debugMessage: '$where: not JSON',
            cause: e,
            stackTrace: stackTrace,
          ),
        );
      }
    }
    final debugMessage = '$where: HTTP $status';
    _logger?.warning('GET $debugMessage');
    return Err(switch (status) {
      404 || 410 => NotFoundFailure(debugMessage: debugMessage),
      401 || 403 => AccessDeniedFailure(debugMessage: debugMessage),
      429 => RateLimitedFailure(
        retryAfter: _retryAfter(response.headers['retry-after']),
        debugMessage: debugMessage,
      ),
      >= 500 && < 600 => ServerFailure(
        statusCode: status,
        debugMessage: debugMessage,
      ),
      _ => InvalidResponseFailure(debugMessage: debugMessage),
    });
  }

  static bool _isTransient(AppFailure failure) => switch (failure) {
    TimeoutFailure() => true,
    ServerFailure(:final statusCode) =>
      statusCode == 502 || statusCode == 503 || statusCode == 504,
    _ => false,
  };

  /// Seconds form only; the HTTP-date form is rare for APIs.
  static Duration? _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  static Future<void> _wait(Duration delay, Cancellation? cancellation) =>
      Future.any([Future<void>.delayed(delay), ?cancellation?.whenCancelled]);

  static String _redacted(Uri uri) => '${uri.host}${uri.path}';
}
