import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/data/settings/in_memory_settings_store.dart';
import 'package:music_app/domain/settings/app_settings.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

import '../../helpers/aura_app_harness.dart';

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

Color backgroundOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AuraTabBar))).scaffoldBackgroundColor;

void main() {
  late InMemorySettingsStore store;

  Future<void> pump(
    WidgetTester tester, {
    AppSettings? initial,
    TestDevice device = iPhone15,
    double textScale = 1,
  }) async {
    store = InMemorySettingsStore();
    await pumpAuraApp(
      tester,
      device: device,
      textScale: textScale,
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        if (initial != null) initialSettingsProvider.overrideWithValue(initial),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(iconButton(AuraStrings.settings));
    await tester.pumpAndSettle();
  }

  testWidgets('the theme chosen at the last launch shows from the start', (
    tester,
  ) async {
    await pump(tester, initial: const AppSettings(theme: ThemeChoice.forest));
    expect(backgroundOf(tester), AuraColors.forest.background);
  });

  testWidgets('picking a theme recolors the app and is saved', (tester) async {
    await pump(tester);
    expect(backgroundOf(tester), AuraColors.dark.background);
    await openSettings(tester);
    expect(find.text(AuraStrings.settings), findsOneWidget);

    await tester.tap(find.text(AuraStrings.themeRose));
    await tester.pumpAndSettle();
    expect(backgroundOf(tester), AuraColors.rose.background);
    expect(
      Theme.of(tester.element(find.byType(AuraTabBar))).brightness,
      Brightness.light,
    );
    expect((await store.load()).theme, ThemeChoice.rose);
  });

  testWidgets('each theme is announced with its name and selection', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await openSettings(tester);
    expect(
      tester.getSemantics(find.text(AuraStrings.themeNeon)),
      isSemantics(
        label: AuraStrings.themeNeon,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    expect(
      tester.getSemantics(find.text(AuraStrings.themeMidnight)),
      isSemantics(
        label: AuraStrings.themeMidnight,
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('recent searches can be cleared from settings', (tester) async {
    await pump(tester, initial: const AppSettings(recentSearches: ['lofi']));
    await openSettings(tester);
    await tester.tap(find.text(AuraStrings.clearSearchHistory));
    await tester.pumpAndSettle();
    expect(find.text(AuraStrings.noRecentSearches), findsOneWidget);
    expect((await store.load()).recentSearches, isEmpty);
  });

  for (final device in [iPhoneSE, iPhone15Landscape]) {
    testWidgets('$device, largest text: settings lay out', (tester) async {
      await pump(tester, device: device, textScale: 3);
      await openSettings(tester);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
