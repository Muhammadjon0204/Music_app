/// An expected, recoverable failure.
///
/// The presentation layer picks user-facing text from the subtype.
/// [debugMessage], [cause] and [stackTrace] are for developers only and must
/// never be shown to users.
sealed class AppFailure {
  const AppFailure({this.debugMessage, this.cause, this.stackTrace});

  final String? debugMessage;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType(${debugMessage ?? ''})';
}

/// A file is missing, moved, or the app lost permission to read it.
final class FileAccessFailure extends AppFailure {
  const FileAccessFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// The audio format or file content cannot be decoded.
final class UnsupportedMediaFailure extends AppFailure {
  const UnsupportedMediaFailure({
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The user or the system denied a required permission.
final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// No connection: the device is offline or the host cannot be reached.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// A remote service did not answer in time.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// A remote service failed on its side (HTTP 5xx).
final class ServerFailure extends AppFailure {
  const ServerFailure({
    this.statusCode,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// Too many requests (HTTP 429). [retryAfter] is the server's hint, if any.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    this.retryAfter,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  final Duration? retryAfter;
}

/// The requested item does not exist (any more), e.g. HTTP 404.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// The service refused access (HTTP 401/403, geo-blocked, gated content).
final class AccessDeniedFailure extends AppFailure {
  const AccessDeniedFailure({
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The service answered with data the app cannot understand.
final class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure({
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// A source does not offer this feature at all (e.g. search on a provider
/// that only supports opening links). Not an error of the moment.
final class FeatureUnavailableFailure extends AppFailure {
  const FeatureUnavailableFailure({
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The operation was cancelled because its result is no longer wanted.
/// Not shown to users.
final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// Local database or disk failure, including running out of space.
final class StorageFailure extends AppFailure {
  const StorageFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// The audio engine failed for a reason not covered by a more specific type.
final class PlaybackFailure extends AppFailure {
  const PlaybackFailure({super.debugMessage, super.cause, super.stackTrace});
}

/// Anything not anticipated. Seeing this in logs means a case is unhandled.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.debugMessage, super.cause, super.stackTrace});
}
