import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';
import 'package:music_app/presentation/design_system/tokens/aura_motion.dart';

/// Equal-width tabs on a pill track; the selected one sits on a sliding
/// highlight. Each segment is a button announced as selected or not.
class AuraSegmentedControl<T> extends StatelessWidget {
  const AuraSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  /// Value and label of each segment, in order.
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final index = segments.indexWhere((s) => s.$1 == selected);
    final count = segments.length;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AuraRadii.pill),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: AuraMotion.fade(context, AuraMotion.normal),
              curve: AuraMotion.emphasized,
              alignment: Alignment(
                count == 1
                    ? 0
                    : -1 + 2 * index.clamp(0, count - 1) / (count - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AuraRadii.pill),
                    border: Border.all(color: colors.border),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (value, label) in segments)
                Expanded(
                  child: AuraPressable(
                    onPressed: () => onSelected(value),
                    selected: value == selected,
                    feedback: AuraPressFeedback.opacity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AuraSizes.minTouchTarget,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpacing.sm,
                            vertical: AuraSpacing.xs,
                          ),
                          child: Text(
                            label,
                            style: text.footnote.copyWith(
                              color: value == selected
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
