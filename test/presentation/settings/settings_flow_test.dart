import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/data/settings/in_memory_settings_store.dart';
import 'package:music_app/domain/settings/app_settings.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/settings/settings_screen.dart';

import '../../helpers/aura_app_harness.dart';

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

final settingsTab = find.descendant(
  of: find.byType(AuraTabBar),
  matching: find.text(AuraStrings.settings),
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

  /// Scrolls the Settings tab until [finder] is on screen, then taps it.
  Future<void> tapInSettings(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(settingsTab);
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
    expect(find.text(AuraStrings.appearance), findsOneWidget);

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
    await tapInSettings(tester, find.text(AuraStrings.clearSearchHistory));
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

  testWidgets('Settings is the fourth tab', (tester) async {
    await pump(tester);
    expect(
      tester
          .widget<AuraTabBar>(find.byType(AuraTabBar))
          .items
          .map((i) => i.label),
      [
        AuraStrings.tabHome,
        AuraStrings.tabSearch,
        AuraStrings.tabLibrary,
        AuraStrings.settings,
      ],
    );
    await openSettings(tester);
    expect(find.text(AuraStrings.sleepTimer), findsOneWidget);
    expect(find.text(AuraStrings.sleepOff), findsOneWidget);
  });

  testWidgets('the sleep timer is set from Settings', (tester) async {
    await pump(tester);
    await openSettings(tester);
    await tester.tap(find.text(AuraStrings.sleepTimer));
    await tester.pumpAndSettle();
    // Nothing is playing: no "end of track" choice, and no "off" yet.
    expect(find.text(AuraStrings.sleepAfterTrack), findsNothing);
    expect(find.text(AuraStrings.sleepTurnOff), findsNothing);

    await tester.tap(find.text(AuraStrings.sleepIn(30)));
    await tester.pumpAndSettle();
    // pumpAuraApp's clock is 09:00.
    expect(find.text(AuraStrings.sleepUntil('09:30')), findsOneWidget);

    await tester.tap(find.text(AuraStrings.sleepTimer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuraStrings.sleepTurnOff));
    await tester.pumpAndSettle();
    expect(find.text(AuraStrings.sleepOff), findsOneWidget);
  });

  testWidgets('music sources say honestly what is connected', (tester) async {
    await pump(tester);
    await openSettings(tester);
    await tapInSettings(tester, find.text(AuraStrings.musicSourcesHint));

    expect(find.text(AuraStrings.sourceLocal), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text(AuraStrings.sourceSpotifyDescription), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(AuraStrings.sourceYouTubeMusicDescription),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(AuraStrings.sourceUnavailable), findsOneWidget);
  });
}
