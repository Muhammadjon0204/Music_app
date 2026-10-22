import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Play/pause with an icon morph. Filled circle when [diameter] is set.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.isWaiting = false,
    this.diameter,
    this.iconSize = AuraSizes.iconLg,
  });

  /// Shows "pause" (playback is on or about to be).
  final bool isPlaying;

  /// Audio is loading or buffering: a spinner replaces the glyph, and the
  /// button still pauses.
  final bool isWaiting;
  final VoidCallback? onPressed;
  final double? diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final reduced = AuraMotion.isReduced(context);
    final diameter = this.diameter;

    Widget glyph = AnimatedSwitcher(
      duration: AuraMotion.fade(context, AuraMotion.fast),
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (reduced) return faded;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
          child: faded,
        );
      },
      child: isWaiting
          ? SizedBox.square(
              key: const ValueKey('waiting'),
              dimension: iconSize,
              child: CupertinoActivityIndicator(
                color: diameter != null ? colors.onAccent : colors.textPrimary,
                radius: iconSize * 0.4,
              ),
            )
          : Icon(
              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              key: ValueKey(isPlaying),
              size: iconSize,
              color: diameter != null ? colors.onAccent : colors.textPrimary,
            ),
    );

    if (diameter != null) {
      glyph = Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
          boxShadow: onPressed != null ? colors.accentGlow : null,
        ),
        child: glyph,
      );
    }

    return AuraPressable(
      onPressed: onPressed,
      semanticLabel: isPlaying ? AuraStrings.pause : AuraStrings.play,
      haptic: true,
      feedback: diameter != null
          ? AuraPressFeedback.scale
          : AuraPressFeedback.opacity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AuraSizes.minTouchTarget,
          minHeight: AuraSizes.minTouchTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: glyph),
      ),
    );
  }
}
