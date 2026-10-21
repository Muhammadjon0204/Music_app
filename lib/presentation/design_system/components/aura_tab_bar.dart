import 'package:flutter/widgets.dart';
import 'package:music_app/presentation/design_system/components/aura_pressable.dart';
import 'package:music_app/presentation/design_system/theme/aura_theme_context.dart';
import 'package:music_app/presentation/design_system/tokens/aura_dimensions.dart';

class AuraTabItem {
  const AuraTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;

  /// Shown when selected, so the state is not conveyed by color alone.
  final IconData selectedIcon;
  final String label;
}

/// Bottom tab bar. Includes the bottom safe-area inset.
class AuraTabBar extends StatelessWidget {
  const AuraTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AuraTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AuraSizes.tabBarHeight),
          child: Row(
            children: [
              for (final (index, item) in items.indexed)
                Expanded(
                  child: _Tab(
                    item: item,
                    selected: index == currentIndex,
                    onPressed: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final AuraTabItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final color = selected ? colors.accentText : colors.textSecondary;
    return AuraPressable(
      onPressed: onPressed,
      selected: selected,
      feedback: AuraPressFeedback.opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              size: AuraSizes.iconLg,
              color: color,
            ),
            const SizedBox(height: AuraSpacing.xxs),
            Text(
              item.label,
              style: context.auraText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
