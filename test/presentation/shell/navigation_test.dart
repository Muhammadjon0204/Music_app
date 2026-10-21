import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

import '../../helpers/aura_app_harness.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

void main() {
  testWidgets('tabs switch screens and keep their state', (tester) async {
    await pumpAuraApp(tester);

    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Найдите музыку'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'дождь');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
    expect(find.text('По запросу «дождь» ничего не найдено'), findsOneWidget);

    await tester.tap(tab('Библиотека'));
    await tester.pumpAndSettle();
    expect(find.text('Библиотека пуста'), findsOneWidget);

    await tester.tap(tab('Поиск'));
    await tester.pumpAndSettle();
    expect(find.text('дождь'), findsOneWidget);
    expect(find.text('По запросу «дождь» ничего не найдено'), findsOneWidget);
  });

  testWidgets('Home search field opens Search with the keyboard focused', (
    tester,
  ) async {
    await pumpAuraApp(tester);

    await tester.tap(find.text(AuraStrings.searchPlaceholder));
    await tester.pumpAndSettle();

    expect(find.text('Найдите музыку'), findsOneWidget);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('selected tab is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAuraApp(tester);

    final homeTab = find.ancestor(
      of: tab('Главная'),
      matching: find.byType(AuraPressable),
    );
    expect(
      tester.getSemantics(homeTab),
      isSemantics(
        label: 'Главная',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('dev gallery opens inside the Home tab; re-tapping Home '
      'returns to its root', (tester) async {
    await pumpAuraApp(tester);

    await tester.tap(iconButton(AuraStrings.devGallery));
    // The gallery has a looping spinner, so pump a fixed time instead of
    // waiting for all animations to settle. The first frame of a push is
    // offstage (for Hero measurement); the second runs the transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Дизайн-система'), findsOneWidget);
    expect(find.byType(AuraTabBar), findsOneWidget);

    await tester.tap(tab('Главная'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Дизайн-система'), findsNothing);
    expect(find.text('Доброе утро'), findsOneWidget);
  });
}
