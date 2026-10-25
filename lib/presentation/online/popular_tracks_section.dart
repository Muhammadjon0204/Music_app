import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// A compact failure with a retry button, for one section of a screen.
class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headline),
          const SizedBox(height: AuraSpacing.xxs),
          Text(message, style: text.subhead),
          const SizedBox(height: AuraSpacing.md),
          AuraButton(
            label: AuraStrings.retry,
            variant: AuraButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Exposed for the search screen's per-provider errors.
class InlineErrorBox extends StatelessWidget {
  const InlineErrorBox({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = failureText(error);
    return _InlineError(title: title, message: message, onRetry: onRetry);
  }
}
