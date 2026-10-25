import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// Icon toggle such as shuffle or repeat. "On" is shown by a highlight
/// shape as well as color, and announced by VoiceOver. Taps give a light
/// haptic, like other playback controls.
class AuraToggleButton extends StatelessWidget {
  const AuraToggleButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.isOn,
    required this.onPressed,
    this.iconSize = AuraSizes.iconLg,
  });

  final IconData icon;
  final String semanticLabel;
  final bool isOn;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return AuraPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      toggled: isOn,
      haptic: true,
      feedback: AuraPressFeedback.opacity,
      child: SizedBox.square(
        dimension: AuraSizes.minTouchTarget,
        child: Center(
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            padding: const EdgeInsets.all(AuraSpacing.xs + 2),
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: isOn ? 1 : 0),
              borderRadius: BorderRadius.circular(AuraRadii.sm),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isOn ? colors.accentText : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
