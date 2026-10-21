import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

import '../helpers/aura_app_harness.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

final hint = find.text('Найдите музыку');
final anyNoResults = find.textContaining('ничего не найдено');

Future<void> openSearch(
  WidgetTester tester, {
  TestDevice device = iPhone15,
  double textScale = 1,
}) async {
  await pumpAuraApp(tester, device: device, textScale: textScale);
  await tester.tap(tab('Поиск'));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String text) =>
    tester.enterText(find.byType(CupertinoSearchTextField), text);

void main() {
  testWidgets('400-character query without spaces lays out', (tester) async {
    await openSearch(tester, device: iPhoneSE, textScale: 2);
    await type(tester, 'а' * 400);
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();

    expect(anyNoResults, findsOneWidget);
  });

  testWidgets('emoji and mixed scripts are kept as typed', (tester) async {
    await openSearch(tester);
    await type(tester, '🎧 Ночь 夜 — night');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();

    expect(
      find.text('По запросу «🎧 Ночь 夜 — night» ничего не найдено'),
      findsOneWidget,
    );
  });

  testWidgets('whitespace-only input keeps the hint', (tester) async {
    await openSearch(tester);
    await type(tester, '     ');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();

    expect(hint, findsOneWidget);
    expect(anyNoResults, findsNothing);
  });

  testWidgets('clearing before the debounce never flashes "no results"', (
    tester,
  ) async {
    await openSearch(tester);
    await type(tester, 'abc');
    await tester.pump(const Duration(milliseconds: 100));
    await type(tester, '');

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(anyNoResults, findsNothing);
    }
    expect(hint, findsOneWidget);
  });

  testWidgets('clear button returns to the hint immediately', (tester) async {
    await openSearch(tester);
    await type(tester, 'abc');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
    expect(anyNoResults, findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    expect(hint, findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets('tapping outside the field hides the keyboard', (tester) async {
    await openSearch(tester);
    await tester.tap(find.byType(CupertinoSearchTextField));
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);

    await tester.tap(hint);
    await tester.pump();

    expect(field.focusNode.hasFocus, isFalse);
  });
}
