import 'package:flutter/cupertino.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

/// Section title with an optional "see all" action. The action is shown only
/// when it does something.
class AuraSectionHeader extends StatelessWidget {
  const AuraSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must be provided together',
       );

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final actionLabel = this.actionLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: text.title3),
            ),
          ),
          if (actionLabel != null)
            AuraPressable(
              onPressed: onAction,
              feedback: AuraPressFeedback.opacity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AuraSizes.minTouchTarget,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel, style: text.footnote),
                    const SizedBox(width: AuraSpacing.xxs),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
