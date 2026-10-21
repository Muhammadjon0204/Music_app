import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/domain/home/home_feed.dart';

/// Device sizes used across layout tests (physical size, pixel ratio).
const iPhoneSE = (Size(750, 1334), 2.0);
const iPhone15 = (Size(1179, 2556), 3.0);

/// Pumps the full app (router, shell, theme) with test bindings.
Future<void> pumpAuraApp(
  WidgetTester tester, {
  HomeFeedSource homeFeedSource = const DemoHomeFeedSource(),
  DateTime? now,
  List<Override> overrides = const [],
  (Size, double) device = iPhone15,
  double textScale = 1,
}) async {
  tester.view.physicalSize = device.$1;
  tester.view.devicePixelRatio = device.$2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
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
