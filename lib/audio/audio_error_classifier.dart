import 'package:music_app/audio/audio_engine.dart';

/// Which platform reported an error: the same number means different
/// things on each.
enum AudioPlatform { apple, android, web, other }

/// Maps what just_audio reports for an error to an [AudioErrorKind].
///
/// Only meanings documented by the platform are used; everything else is
/// [AudioErrorKind.unknown] rather than a guess. What each platform
/// passes up (checked in just_audio 0.10.6 sources):
/// - iOS/macOS: `NSError.code` of the failed player item. Network failures
///   often arrive wrapped as the generic -11800, which stays unknown.
/// - Android: only `ExoPlaybackException.type`, no HTTP status.
/// - Web: `MediaError.code`.
AudioErrorKind classifyAudioError({
  required int code,
  String? message,
  required AudioPlatform platform,
}) {
  final fromStatus = _httpStatusIn(message);
  if (fromStatus != null) return fromStatus;

  return switch (platform) {
    AudioPlatform.apple => switch (code) {
      // NSURLErrorNotConnectedToInternet, CannotConnectToHost,
      // CannotFindHost, NetworkConnectionLost, DNSLookupFailed,
      // DataNotAllowed.
      -1009 ||
      -1004 ||
      -1003 ||
      -1005 ||
      -1006 ||
      -1020 => AudioErrorKind.networkUnavailable,
      -1001 => AudioErrorKind.timeout, // NSURLErrorTimedOut
      -1100 => AudioErrorKind.fileMissing, // NSURLErrorFileDoesNotExist
      // NSURLErrorUserAuthenticationRequired, NoPermissionsToReadFile.
      -1013 || -1102 => AudioErrorKind.accessDenied,
      -11850 => AudioErrorKind.server, // AVErrorServerIncorrectlyConfigured
      // AVErrorFileFormatNotRecognized, AVErrorFailedToParse,
      // AVErrorDecodeFailed.
      -11828 || -11829 || -11821 => AudioErrorKind.unsupportedFormat,
      _ => AudioErrorKind.unknown,
    },
    AudioPlatform.android => switch (code) {
      1 => AudioErrorKind.unsupportedFormat, // TYPE_RENDERER
      _ => AudioErrorKind.unknown,
    },
    AudioPlatform.web => switch (code) {
      2 => AudioErrorKind.networkUnavailable, // MEDIA_ERR_NETWORK
      3 => AudioErrorKind.unsupportedFormat, // MEDIA_ERR_DECODE
      _ => AudioErrorKind.unknown,
    },
    AudioPlatform.other => AudioErrorKind.unknown,
  };
}

final _statusPattern = RegExp(
  r'(?:response code|status code|http(?: status)?(?: error)?)\D{0,3}(\d{3})\b',
  caseSensitive: false,
);

/// An HTTP status quoted in a message, e.g. "Response code: 404".
AudioErrorKind? _httpStatusIn(String? message) {
  if (message == null) return null;
  final match = _statusPattern.firstMatch(message);
  if (match == null) return null;
  final status = int.parse(match.group(1)!);
  return switch (status) {
    404 || 410 => AudioErrorKind.notFound,
    401 || 403 => AudioErrorKind.accessDenied,
    429 => AudioErrorKind.rateLimited,
    >= 500 && < 600 => AudioErrorKind.server,
    _ => null,
  };
}
