import 'dart:async';

/// Lets the caller say "I no longer need this result" (a newer search
/// replaced it, the user switched tracks). Work that supports it stops
/// early and finishes with a CancelledFailure.
final class Cancellation {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called; never completes with an error.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
