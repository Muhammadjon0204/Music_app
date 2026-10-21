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

/// No connection, timeout, or an invalid response from a remote service.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.debugMessage, super.cause, super.stackTrace});
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
