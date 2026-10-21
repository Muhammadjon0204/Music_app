import 'package:music_app/core/error/app_failure.dart';

/// Outcome of an operation that can fail in an expected way.
///
/// Use exceptions only for programming errors; return [Err] for failures a
/// user can run into (missing file, no network, permission denied).
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}
