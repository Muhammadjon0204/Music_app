import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/domain/home/home_feed.dart';

/// A device: logical size, pixel ratio and safe-area insets (logical).
class TestDevice {
  const TestDevice(
    this.name,
    this.size,
    this.pixelRatio, {
    this.padding = EdgeInsets.zero,
  });

  final String name;
  final Size size;
  final double pixelRatio;

  /// Status bar / Dynamic Island, home indicator, landscape side insets.
  final EdgeInsets padding;

  @override
  String toString() => name;
}

const iPhoneSE = TestDevice(
  'iPhone SE',
  Size(375, 667),
  2,
  padding: EdgeInsets.only(top: 20),
);
const iPhone15 = TestDevice(
  'iPhone 15',
  Size(393, 852),
  3,
  padding: EdgeInsets.only(top: 59, bottom: 34),
);
const iPhone16ProMax = TestDevice(
  'iPhone 16 Pro Max',
  Size(440, 956),
  3,
  padding: EdgeInsets.only(top: 62, bottom: 34),
);
const iPhoneSELandscape = TestDevice('iPhone SE landscape', Size(667, 375), 2);
const iPhone15Landscape = TestDevice(
  'iPhone 15 landscape',
  Size(852, 393),
  3,
  padding: EdgeInsets.only(left: 59, right: 59, bottom: 21),
);
const iPadMini = TestDevice(
  'iPad mini',
  Size(744, 1133),
  2,
  padding: EdgeInsets.only(top: 24, bottom: 20),
);

const allDevices = [
  iPhoneSE,
  iPhone15,
  iPhone16ProMax,
  iPhoneSELandscape,
  iPhone15Landscape,
  iPadMini,
];

/// iOS text sizes: default, largest standard, and two accessibility sizes.
const allTextScales = [1.0, 1.35, 2.0, 3.0];

void applyDevice(WidgetTester tester, TestDevice device) {
  final ratio = device.pixelRatio;
  final padding = FakeViewPadding(
    left: device.padding.left * ratio,
    top: device.padding.top * ratio,
    right: device.padding.right * ratio,
    bottom: device.padding.bottom * ratio,
  );
  tester.view
    ..physicalSize = device.size * ratio
    ..devicePixelRatio = ratio
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// Pumps the full app (router, shell, theme) with test bindings.
Future<void> pumpAuraApp(
  WidgetTester tester, {
  HomeFeedSource homeFeedSource = const DemoHomeFeedSource(),
  DateTime? now,
  List<Override> overrides = const [],
  TestDevice device = iPhone15,
  double textScale = 1,
}) async {
  applyDevice(tester, device);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final fixedNow = now ?? DateTime(2026, 1, 1, 9);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeFeedSourceProvider.overrideWithValue(homeFeedSource),
        clockProvider.overrideWithValue(() => fixedNow),
        ...overrides,
      ],
      child: const AuraApp(),
    ),
  );
  // Let the feed future and router settle.
  await tester.pump();
  await tester.pump();
}
