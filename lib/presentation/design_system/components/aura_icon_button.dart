import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Icon-only button with a hit area of at least 44×44 pt.
/// [semanticLabel] is required because there is no visible text.
class AuraIconButton extends StatelessWidget {
  const AuraIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.iconSize = AuraSizes.iconLg,
    this.toggled,
  }) : diameter = null,
       backgroundColor = null;

  /// Circular filled button, e.g. play/pause.
  const AuraIconButton.filled({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    required double this.diameter,
    this.color,
    this.backgroundColor,
    this.iconSize = AuraSizes.iconLg,
    this.toggled,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double iconSize;

  /// For on/off actions such as "favorite". Pair it with a different icon
  /// for each state so the state is not conveyed by color alone.
  final bool? toggled;

  /// Set only by [AuraIconButton.filled].
  final double? diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final diameter = this.diameter;
    final enabled = onPressed != null;

    Widget glyph = Icon(
      icon,
      size: iconSize,
      color: color ?? (diameter != null ? colors.onAccent : colors.textPrimary),
    );

    if (diameter != null) {
      glyph = Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.accent,
          shape: BoxShape.circle,
        ),
        child: glyph,
      );
    }

    return AuraPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      toggled: toggled,
      feedback: diameter != null
          ? AuraPressFeedback.scale
          : AuraPressFeedback.opacity,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AuraSizes.minTouchTarget,
            minHeight: AuraSizes.minTouchTarget,
          ),
          child: Center(widthFactor: 1, heightFactor: 1, child: glyph),
        ),
      ),
    );
  }
}
