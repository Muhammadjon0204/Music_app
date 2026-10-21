import 'package:flutter_test/flutter_test.dart';

import 'helpers/aura_app_harness.dart';

void main() {
  testWidgets('App boots into Home with the tab bar', (tester) async {
    await pumpAuraApp(tester);

    expect(find.text('Доброе утро'), findsOneWidget);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Библиотека'), findsOneWidget);
  });
}
