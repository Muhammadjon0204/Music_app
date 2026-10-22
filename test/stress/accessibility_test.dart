import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';
import 'package:music_app/presentation/player/now_playing_screen.dart';
import 'package:music_app/presentation/player/queue_screen.dart';

import '../helpers/aura_app_harness.dart';
import '../helpers/fakes.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Future<void> pumpWithPlayer(WidgetTester tester) => pumpAuraApp(
  tester,
  overrides: [
    playbackControllerProvider.overrideWithValue(
      FakePlaybackController(
        PlaybackSnapshot(
          queue: [
            Track(
              id: const TrackId('t'),
              title: 'Трек',
              artistName: 'Исполнитель',
              sources: const [LocalFileSource('t.mp3')],
            ),
          ],
          currentIndex: 0,
        ),
      ),
    ),
  ],
);

Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  // The rendered-pixel check is unreliable on Linux: Cyrillic is missing
  // from the test font and falls back to a thin, anti-aliased system font,
  // so the sampler mostly sees half-blended edge pixels (CI measured 1.41
  // for text whose colors are 6.8:1). The exact color contrast of every
  // text token is verified on all platforms in contrast_test.dart.
  if (!Platform.isLinux) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
}

void main() {
  for (final label in ['Главная', 'Поиск', 'Библиотека']) {
    testWidgets('$label: 44pt targets, labels, rendered text contrast', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpWithPlayer(tester);
      await tester.tap(tab(label));
      await tester.pumpAndSettle();

      await expectGuidelines(tester);
      handle.dispose();
    });
  }

  testWidgets('Now Playing and the queue meet the same guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpWithPlayer(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(AuraArtwork),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await expectGuidelines(tester);

    await tester.tap(find.text(AuraStrings.queue));
    await tester.pumpAndSettle();
    expect(find.byType(QueueScreen), findsOneWidget);
    await expectGuidelines(tester);
    handle.dispose();
  });

  testWidgets('component gallery meets the guidelines along its full length', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAuraApp(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AuraIconButton && w.semanticLabel == AuraStrings.devGallery,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Guidelines only inspect what is on screen, so walk the whole page.
    final scrollable = find.byType(Scrollable).last;
    for (var step = 0; step < 12; step++) {
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
    }
    handle.dispose();
  });

  testWidgets('every icon-only control in the app has a spoken label', (
    tester,
  ) async {
    await pumpWithPlayer(tester);

    final buttons = tester.widgetList<AuraIconButton>(
      find.byType(AuraIconButton, skipOffstage: false),
    );
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.semanticLabel.trim(), isNotEmpty);
    }
  });

  testWidgets('screen titles are announced as headings', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAuraApp(tester);

    expect(
      tester.getSemantics(find.text('Доброе утро')),
      isSemantics(isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('iOS edge swipe goes back from a pushed screen', (tester) async {
    await pumpAuraApp(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is AuraIconButton && w.semanticLabel == AuraStrings.devGallery,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Дизайн-система'), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(5, 400));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Дизайн-система'), findsNothing);
    expect(find.text('Доброе утро'), findsOneWidget);
  });
}
