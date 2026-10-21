import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/app/app.dart';

void main() {
  testWidgets('App boots into the themed component gallery', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AuraApp()));

    expect(find.text('Дизайн-система'), findsOneWidget);
  });
}
