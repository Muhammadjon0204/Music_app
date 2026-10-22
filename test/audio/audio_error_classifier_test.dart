import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/audio_error_classifier.dart';

AudioErrorKind _apple(int code, [String? message]) => classifyAudioError(
  code: code,
  message: message,
  platform: AudioPlatform.apple,
);

void main() {
  group('iOS / macOS', () {
    test('documented network codes', () {
      expect(_apple(-1009), AudioErrorKind.networkUnavailable);
      expect(_apple(-1005), AudioErrorKind.networkUnavailable);
      expect(_apple(-1001), AudioErrorKind.timeout);
      expect(_apple(-1100), AudioErrorKind.fileMissing);
      expect(_apple(-11828), AudioErrorKind.unsupportedFormat);
      expect(_apple(-11850), AudioErrorKind.server);
    });

    test('the generic AVFoundation error is not guessed', () {
      expect(
        _apple(-11800, 'The operation could not be completed'),
        AudioErrorKind.unknown,
      );
    });
  });

  test('Android only knows the renderer type', () {
    AudioErrorKind android(int code) => classifyAudioError(
      code: code,
      message: 'Source error',
      platform: AudioPlatform.android,
    );
    expect(android(1), AudioErrorKind.unsupportedFormat);
    // TYPE_SOURCE says nothing about the cause.
    expect(android(0), AudioErrorKind.unknown);
  });

  test('web media error codes', () {
    AudioErrorKind web(int code) =>
        classifyAudioError(code: code, platform: AudioPlatform.web);
    expect(web(2), AudioErrorKind.networkUnavailable);
    expect(web(3), AudioErrorKind.unsupportedFormat);
    // "Source not supported" can mean a bad URL or a bad format.
    expect(web(4), AudioErrorKind.unknown);
  });

  test('an HTTP status quoted in the message wins on any platform', () {
    for (final platform in AudioPlatform.values) {
      AudioErrorKind kind(String message) =>
          classifyAudioError(code: 0, message: message, platform: platform);
      expect(kind('Response code: 404'), AudioErrorKind.notFound);
      expect(kind('HTTP 403 Forbidden'), AudioErrorKind.accessDenied);
      expect(kind('status code 429'), AudioErrorKind.rateLimited);
      expect(kind('Response code: 503'), AudioErrorKind.server);
    }
  });

  test('numbers that are not HTTP statuses are ignored', () {
    expect(
      classifyAudioError(
        code: 0,
        message: 'Track 404 of album',
        platform: AudioPlatform.other,
      ),
      AudioErrorKind.unknown,
    );
  });
}
