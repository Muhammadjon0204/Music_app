import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

enum AuraButtonVariant {
  /// Filled accent pill. One per screen: the main action.
  primary,

  /// Outlined pill for alternative actions.
  secondary,
}

enum AuraButtonSize { medium, large }

class AuraButton extends StatelessWidget {
  const AuraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AuraButtonVariant.primary,
    this.size = AuraButtonSize.medium,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;

  /// Null renders the button disabled.
  final VoidCallback? onPressed;
  final IconData? icon;
  final AuraButtonVariant variant;
  final AuraButtonSize size;

  /// Fill the available width.
  final bool expand;

  /// Shows a spinner, ignores taps, and keeps the button's size unchanged.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final isPrimary = variant == AuraButtonVariant.primary;
    final enabled = onPressed != null && !isLoading;
    final foreground = isPrimary ? colors.onAccent : colors.textPrimary;
    final isLarge = size == AuraButtonSize.large;

    final label = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AuraSizes.iconMd, color: foreground),
          const SizedBox(width: AuraSpacing.sm),
        ],
        Flexible(
          child: Text(
            this.label,
            style: context.auraText.button.copyWith(color: foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: isLarge ? AuraSizes.buttonLarge : AuraSizes.buttonMedium,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPrimary ? colors.accent : null,
          borderRadius: BorderRadius.circular(AuraRadii.pill),
          border: isPrimary ? null : Border.all(color: colors.borderStrong),
          boxShadow: isPrimary && enabled ? colors.accentGlow : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLarge ? AuraSpacing.xxl : AuraSpacing.xl,
            vertical: AuraSpacing.sm,
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Visibility(
                  visible: !isLoading,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  maintainSemantics: true,
                  child: label,
                ),
                if (isLoading)
                  CupertinoActivityIndicator(color: foreground, radius: 9),
              ],
            ),
          ),
        ),
      ),
    );

    if (expand) button = SizedBox(width: double.infinity, child: button);

    return AuraPressable(
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled || isLoading ? 1 : 0.4,
        duration: AuraMotion.fast,
        child: button,
      ),
    );
  }
}
