import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/home/home_screen.dart';

import '../../helpers/aura_app_harness.dart';

/// Every tab must lay out without overflow on small and large iPhones,
/// including at double system text size.
void main() {
  const devices = {'iPhone SE': iPhoneSE, 'iPhone 15': iPhone15};

  for (final MapEntry(key: name, value: device) in devices.entries) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('all tabs fit $name at text scale $textScale', (
        tester,
      ) async {
        await pumpAuraApp(tester, device: device, textScale: textScale);

        await tester.scrollUntilVisible(
          find.text('Плейлисты'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(HomeScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );

        for (final label in ['Поиск', 'Библиотека']) {
          await tester.tap(
            find.descendant(
              of: find.byType(AuraTabBar),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Библиотека пуста'), findsOneWidget);
      });
    }
  }
}
