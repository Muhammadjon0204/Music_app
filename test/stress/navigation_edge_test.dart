import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/app/router.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/home/home_screen.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

import '../helpers/aura_app_harness.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String label) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == label,
);

EditableText searchField(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

Future<void> typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(CupertinoSearchTextField), query);
  await tester.pump(SearchQueryController.debounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unknown location falls back to Home, no error page', (
    tester,
  ) async {
    await pumpAuraApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuraApp)),
    );

    container.read(routerProvider).go('/does/not/exist');
    await tester.pumpAndSettle();

    expect(find.text('Доброе утро'), findsOneWidget);
    expect(find.textContaining('xception'), findsNothing);
    expect(find.textContaining('not found'), findsNothing);
  });

  testWidgets('re-tapping Search keeps query text and results consistent', (
    tester,
  ) async {
    await pumpAuraApp(tester);
    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'ночь');

    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();

    expect(searchField(tester).controller.text, 'ночь');
    expect(find.text('По запросу «ночь» ничего не найдено'), findsOneWidget);
  });

  testWidgets('opening Search from Home keeps an existing query', (
    tester,
  ) async {
    await pumpAuraApp(tester);
    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'ночь');
    await tester.tap(tab('Главная'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AuraStrings.searchPlaceholder).first);
    await tester.pumpAndSettle();

    expect(searchField(tester).controller.text, 'ночь');
    expect(find.text('По запросу «ночь» ничего не найдено'), findsOneWidget);
    expect(searchField(tester).focusNode.hasFocus, isTrue);
  });

  testWidgets('Home search field focuses Search on every tap', (tester) async {
    await pumpAuraApp(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(tab('Главная'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.searchPlaceholder).first);
      await tester.pumpAndSettle();
      expect(searchField(tester).focusNode.hasFocus, isTrue, reason: 'tap $i');

      searchField(tester).focusNode.unfocus();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('rapid tab switching stays stable', (tester) async {
    await pumpAuraApp(tester);
    const labels = ['Поиск', 'Библиотека', 'Главная'];

    for (var i = 0; i < 30; i++) {
      await tester.tap(tab(labels[i % labels.length]));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Доброе утро'), findsOneWidget);
  });

  testWidgets('app can be torn down while a search debounce is pending', (
    tester,
  ) async {
    await pumpAuraApp(tester);
    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'a');

    // The test framework fails if a timer outlives the widget tree.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stays dark when the system is in light mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpAuraApp(tester);

    final theme = Theme.of(tester.element(find.byType(HomeScreen)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AuraColors.dark.background);
  });

  testWidgets('system texts are Russian even on an English device', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpAuraApp(tester);

    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ru'));
    expect(CupertinoLocalizations.of(context).copyButtonLabel, 'Копировать');
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'Назад');
  });

  testWidgets('pushing a screen uses the iOS slide by default', (tester) async {
    await pumpAuraApp(tester);

    await tester.tap(iconButton(AuraStrings.devGallery));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CupertinoPageTransition), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Reduce Motion replaces the slide with a cross-fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpAuraApp(tester);

    await tester.tap(iconButton(AuraStrings.devGallery));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CupertinoPageTransition), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Дизайн-система'), findsOneWidget);
  });
}
