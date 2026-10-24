import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/domain/settings/app_settings.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/settings/theme_choices.dart';

/// Theme choice, recent searches and what the app is. Only settings that
/// really do something.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final text = context.auraText;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(
        top: AuraSpacing.xxl,
        bottom: AuraSpacing.sm,
      ),
      child: AuraSectionHeader(title: title),
    );

    return LibraryPage(
      title: AuraStrings.settings,
      slivers: [
        SliverList.list(
          children: [
            section(AuraStrings.appearance),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.screenHorizontal,
              ),
              child: Text(AuraStrings.themeHint, style: text.subhead),
            ),
            const SizedBox(height: AuraSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.screenHorizontal,
              ),
              child: _ThemeGrid(
                selected: settings.theme,
                onSelected: controller.selectTheme,
              ),
            ),
            section(AuraStrings.searchSettings),
            AuraListTile(
              title: AuraStrings.clearSearchHistory,
              subtitle: settings.recentSearches.isEmpty
                  ? AuraStrings.noRecentSearches
                  : AuraStrings.recentSearches,
              leading: const AuraIconTile(icon: CupertinoIcons.clock),
              onPressed: settings.recentSearches.isEmpty
                  ? null
                  : controller.clearRecentSearches,
            ),
            section(AuraStrings.aboutApp),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.screenHorizontal,
              ),
              child: Text(AuraStrings.aboutMessage, style: text.subhead),
            ),
          ],
        ),
      ],
    );
  }
}

/// The themes as small previews of their own colors, two per row (four on
/// wide screens).
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.selected, required this.onSelected});

  final ThemeChoice selected;
  final ValueChanged<ThemeChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final width =
            (constraints.maxWidth - AuraSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AuraSpacing.md,
          runSpacing: AuraSpacing.md,
          children: [
            for (final theme in ThemeChoice.values)
              SizedBox(
                width: width,
                child: _ThemeCard(
                  theme: theme,
                  selected: theme == selected,
                  onPressed: () => onSelected(theme),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onPressed,
  });

  final ThemeChoice theme;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final current = context.auraColors;
    final text = context.auraText;
    return AuraPressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: theme.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AuraMotion.fast,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuraRadii.lg + 3),
              border: Border.all(
                color: selected ? current.accent : current.border,
                width: 2,
              ),
            ),
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  _ThemePreview(colors: theme.colors),
                  if (selected)
                    Positioned(
                      top: AuraSpacing.sm,
                      right: AuraSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: current.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.checkmark_alt_circle_fill,
                          color: current.accentText,
                          size: AuraSizes.iconLg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AuraSpacing.sm),
          ExcludeSemantics(
            child: Text(
              theme.label,
              style: text.headline.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A miniature screen in the palette: a title, a cover, two rows and the
/// accent button.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.colors});

  final AuraColors colors;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, Color color, {double height = 6}) =>
        FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AuraRadii.pill),
            ),
          ),
        );

    Widget row(List<Color> cover) => Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: cover),
            borderRadius: BorderRadius.circular(AuraRadii.xs),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(0.8, colors.textPrimary, height: 4),
              const SizedBox(height: 3),
              bar(0.5, colors.textSecondary, height: 3),
            ],
          ),
        ),
      ],
    );

    return AspectRatio(
      aspectRatio: 1.05,
      child: Container(
        padding: const EdgeInsets.all(AuraSpacing.md),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AuraRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(0.55, colors.textPrimary, height: 7),
            const SizedBox(height: AuraSpacing.sm),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors.brandGradient,
                  ),
                  borderRadius: BorderRadius.circular(AuraRadii.sm),
                ),
              ),
            ),
            const SizedBox(height: AuraSpacing.sm),
            row(colors.artworkGradients[0]),
            const SizedBox(height: 5),
            row(colors.artworkGradients[1]),
            const SizedBox(height: AuraSpacing.sm),
            Container(
              height: 14,
              width: 46,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(AuraRadii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
