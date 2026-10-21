import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/dev/design_system_gallery_screen.dart';

import '../../helpers/aura_test_app.dart';

/// Lays out every component on real iPhone sizes, including a large
/// Dynamic Type setting. Any overflow fails the test.
void main() {
  const devices = {
    'iPhone SE (375×667)': (Size(750, 1334), 2.0),
    'iPhone 15 (393×852)': (Size(1179, 2556), 3.0),
  };

  for (final MapEntry(key: name, value: (physical, ratio)) in devices.entries) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('gallery fits $name at text scale $textScale', (
        tester,
      ) async {
        tester.view.physicalSize = physical;
        tester.view.devicePixelRatio = ratio;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          auraTestApp(const DesignSystemGalleryScreen(), textScale: textScale),
        );
        await tester.scrollUntilVisible(
          find.text(DesignSystemGalleryScreen.endMarker),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text(DesignSystemGalleryScreen.endMarker), findsOneWidget);
      });
    }
  }
}
