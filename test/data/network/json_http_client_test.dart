import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/network/json_http_client.dart';

final _uri = Uri.parse('https://api.example.test/v1/tracks?query=secret+song');

class _RecordingLogger implements AppLogger {
  final lines = <String>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => lines.add(message);
}

/// A server that answers [responses] in turn and counts requests.
MockClient _server(List<http.Response> responses, {List<int>? calls}) {
  var i = 0;
  return MockClient((request) async {
    calls?.add(i);
    // The last response repeats once the list runs out.
    final response = responses[i < responses.length ? i : responses.length - 1];
    i++;
    return response;
  });
}

/// Never answers; ends only when the request is aborted.
Future<http.StreamedResponse> _neverAnswer(http.BaseRequest request) async {
  if (request case http.Abortable(:final abortTrigger?)) {
    await abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
  return Completer<http.StreamedResponse>().future;
}

MockClient _silentServer() =>
    MockClient.streaming((request, _) => _neverAnswer(request));

JsonHttpClient _client(
  http.Client inner, {
  Duration timeout = const Duration(seconds: 5),
  AppLogger? logger,
}) => JsonHttpClient(
  client: inner,
  timeout: timeout,
  retryDelay: Duration.zero,
  logger: logger,
);

AppFailure _failureOf(Result<Object?> result) => (result as Err).failure;

void main() {
  test('decodes JSON, including non-Latin text', () async {
    final client = _client(
      _server([
        http.Response.bytes(
          utf8.encode(jsonEncode({'title': 'Звезда'})),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ]),
    );
    final result = await client.getJson(_uri);
    expect((result as Ok).value, {'title': 'Звезда'});
  });

  test('404 is "not found" and is not retried', () async {
    final calls = <int>[];
    final client = _client(_server([http.Response('', 404)], calls: calls));
    expect(_failureOf(await client.getJson(_uri)), isA<NotFoundFailure>());
    expect(calls, hasLength(1));
  });

  test('401 and 403 are "access denied"', () async {
    for (final status in [401, 403]) {
      final client = _client(_server([http.Response('', status)]));
      expect(
        _failureOf(await client.getJson(_uri)),
        isA<AccessDeniedFailure>(),
      );
    }
  });

  test('429 reports the server\'s wait hint and is not retried', () async {
    final calls = <int>[];
    final client = _client(
      _server([
        http.Response('', 429, headers: {'retry-after': '30'}),
      ], calls: calls),
    );
    final failure = _failureOf(await client.getJson(_uri));
    expect(failure, isA<RateLimitedFailure>());
    expect(
      (failure as RateLimitedFailure).retryAfter,
      const Duration(seconds: 30),
    );
    expect(calls, hasLength(1));
  });

  test('a transient 503 is retried once, then succeeds', () async {
    final calls = <int>[];
    final client = _client(
      _server([http.Response('', 503), http.Response('[]', 200)], calls: calls),
    );
    expect(await client.getJson(_uri), isA<Ok<Object?>>());
    expect(calls, hasLength(2));
  });

  test('retries are bounded: a persistent 503 fails after two tries', () async {
    final calls = <int>[];
    final client = _client(_server([http.Response('', 503)], calls: calls));
    final failure = _failureOf(await client.getJson(_uri));
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 503);
    expect(calls, hasLength(2));
  });

  test('500 is a server failure without retry', () async {
    final calls = <int>[];
    final client = _client(_server([http.Response('', 500)], calls: calls));
    expect(_failureOf(await client.getJson(_uri)), isA<ServerFailure>());
    expect(calls, hasLength(1));
  });

  test('invalid JSON is an invalid response, not a crash', () async {
    final client = _client(_server([http.Response('<html>oops', 200)]));
    expect(
      _failureOf(await client.getJson(_uri)),
      isA<InvalidResponseFailure>(),
    );
  });

  test('an oversized body is rejected', () async {
    final client = JsonHttpClient(
      client: _server([http.Response('[${'1,' * 100}1]', 200)]),
      maxResponseBytes: 50,
    );
    expect(
      _failureOf(await client.getJson(_uri)),
      isA<InvalidResponseFailure>(),
    );
  });

  test('no network is a network failure', () async {
    final client = _client(
      MockClient((_) async => throw http.ClientException('Failed host lookup')),
    );
    expect(_failureOf(await client.getJson(_uri)), isA<NetworkFailure>());
  });

  test('a silent server times out and the request is aborted', () async {
    final client = JsonHttpClient(
      client: _silentServer(),
      timeout: const Duration(milliseconds: 50),
      maxAttempts: 1,
    );
    expect(_failureOf(await client.getJson(_uri)), isA<TimeoutFailure>());
  });

  test('timeouts are retried a bounded number of times', () async {
    var calls = 0;
    final client = JsonHttpClient(
      client: MockClient.streaming((request, _) {
        calls++;
        return _neverAnswer(request);
      }),
      timeout: const Duration(milliseconds: 30),
      retryDelay: Duration.zero,
    );
    expect(_failureOf(await client.getJson(_uri)), isA<TimeoutFailure>());
    expect(calls, 2);
  });

  test('cancelling aborts the request', () async {
    final client = _client(_silentServer());
    final cancellation = Cancellation();
    final pending = client.getJson(_uri, cancellation: cancellation);
    cancellation.cancel();
    expect(_failureOf(await pending), isA<CancelledFailure>());
  });

  test('an already cancelled request is not sent', () async {
    final calls = <int>[];
    final client = _client(_server([http.Response('[]', 200)], calls: calls));
    final cancellation = Cancellation()..cancel();
    expect(
      _failureOf(await client.getJson(_uri, cancellation: cancellation)),
      isA<CancelledFailure>(),
    );
    expect(calls, isEmpty);
  });

  test('logs never contain the query string', () async {
    final logger = _RecordingLogger();
    final client = _client(_server([http.Response('', 404)]), logger: logger);
    await client.getJson(_uri);
    expect(logger.lines, isNotEmpty);
    expect(logger.lines.join('\n'), isNot(contains('secret')));
  });
}
