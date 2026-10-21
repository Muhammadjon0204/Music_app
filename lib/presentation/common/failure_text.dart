import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// User-facing title and message for an error. Never exposes technical
/// details. The switch is exhaustive, so a new AppFailure subtype will not
/// compile until it gets its own text.
(String title, String message) failureText(Object error) {
  if (error is! AppFailure) {
    return (
      AuraStrings.failureUnexpectedTitle,
      AuraStrings.failureUnexpectedMessage,
    );
  }
  return switch (error) {
    FileAccessFailure() => (
      AuraStrings.failureFileTitle,
      AuraStrings.failureFileMessage,
    ),
    UnsupportedMediaFailure() => (
      AuraStrings.failureMediaTitle,
      AuraStrings.failureMediaMessage,
    ),
    PermissionDeniedFailure() => (
      AuraStrings.failurePermissionTitle,
      AuraStrings.failurePermissionMessage,
    ),
    NetworkFailure() => (
      AuraStrings.failureNetworkTitle,
      AuraStrings.failureNetworkMessage,
    ),
    StorageFailure() => (
      AuraStrings.failureStorageTitle,
      AuraStrings.failureStorageMessage,
    ),
    PlaybackFailure() => (
      AuraStrings.failurePlaybackTitle,
      AuraStrings.failurePlaybackMessage,
    ),
    UnexpectedFailure() => (
      AuraStrings.failureUnexpectedTitle,
      AuraStrings.failureUnexpectedMessage,
    ),
  };
}
