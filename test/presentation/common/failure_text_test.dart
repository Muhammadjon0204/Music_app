import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/presentation/common/failure_text.dart';

void main() {
  const secret = 'SELECT * FROM tracks; token=abc';

  test('every failure type has user text without technical details', () {
    const failures = <AppFailure>[
      FileAccessFailure(debugMessage: secret),
      UnsupportedMediaFailure(debugMessage: secret),
      PermissionDeniedFailure(debugMessage: secret),
      NetworkFailure(debugMessage: secret),
      StorageFailure(debugMessage: secret),
      PlaybackFailure(debugMessage: secret),
      UnexpectedFailure(debugMessage: secret),
      TimeoutFailure(debugMessage: secret),
      ServerFailure(statusCode: 503, debugMessage: secret),
      RateLimitedFailure(debugMessage: secret),
      NotFoundFailure(debugMessage: secret),
      AccessDeniedFailure(debugMessage: secret),
      InvalidResponseFailure(debugMessage: secret),
      FeatureUnavailableFailure(debugMessage: secret),
      CancelledFailure(debugMessage: secret),
    ];
    for (final failure in failures) {
      final (title, message) = failureText(failure);
      expect(title, isNotEmpty);
      expect(message, isNotEmpty);
      expect('$title $message', isNot(contains(secret)));
    }
  });

  test('non-AppFailure errors get the generic text', () {
    final (title, _) = failureText(StateError(secret));
    final (unexpectedTitle, _) = failureText(const UnexpectedFailure());
    expect(title, unexpectedTitle);
  });

  test('network failures are told apart for the user', () {
    final texts = {
      for (final failure in const <AppFailure>[
        NetworkFailure(),
        TimeoutFailure(),
        ServerFailure(),
        RateLimitedFailure(),
        NotFoundFailure(),
        AccessDeniedFailure(),
      ])
        failureText(failure).$1,
    };
    expect(texts, hasLength(6));
  });
}
