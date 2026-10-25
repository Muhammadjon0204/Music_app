import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/app/router.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';
import 'package:music_app/presentation/player/now_playing_screen.dart';
import 'package:music_app/presentation/player/play_pause_button.dart';
import 'package:music_app/presentation/player/player_palette.dart';
import 'package:music_app/presentation/player/queue_screen.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

final hits = DemoCatalog.tones;
const sheetTime = Duration(milliseconds: 600);

Finder inNowPlaying(Finder finder) =>
    find.descendant(of: find.byType(NowPlayingScreen), matching: finder);

Finder iconButton(String label) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == label,
);

Finder toggle(bool Function(AuraToggleButton) test) =>
    find.byWidgetPredicate((w) => w is AuraToggleButton && test(w));

Future<EnginePlaybackController> pumpWithPlayer(
  WidgetTester tester, {
  bool isSilent = true,
  List<Override> extra = const [],
}) async {
  final player = EnginePlaybackController(
    engine: SimulatedAudioEngine(),
    random: Random(1),
  );
  await pumpAuraApp(
    tester,
    overrides: [
      playbackControllerProvider.overrideWithValue(player),
      isSilentPlaybackProvider.overrideWithValue(isSilent),
      ...extra,
    ],
  );
  return player;
}

/// Loads the demo queue paused, so animations can settle.
Future<void> loadHits(
  WidgetTester tester,
  EnginePlaybackController player, {
  int startIndex = 0,
}) async {
  await player.setQueue(hits, startIndex: startIndex);
  await tester.pump();
}

Future<void> openNowPlaying(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MiniPlayerBar),
      matching: find.byType(AuraArtwork),
    ),
  );
  await tester.pump();
  await tester.pump(sheetTime);
}

void main() {
  testWidgets('banner play starts the featured playlist', (tester) async {
    final player = await pumpWithPlayer(tester);

    await tester.tap(iconButton(AuraStrings.playPlaylist('Демо-тоны')));
    await tester.pump();

    expect(player.snapshot.currentTrack, hits.first);
    expect(player.snapshot.isPlaying, isTrue);
    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.text(hits.first.title),
      ),
      findsOneWidget,
    );
    await player.dispose();
  });

  testWidgets('without a player there is no play button on the banner', (
    tester,
  ) async {
    await pumpAuraApp(tester);
    expect(iconButton(AuraStrings.playPlaylist('Демо-тоны')), findsNothing);
  });

  testWidgets('mini player opens Now Playing; the chevron closes it', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);

    await openNowPlaying(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    expect(inNowPlaying(find.text(hits.first.title)), findsOneWidget);
    expect(find.text(AuraStrings.silentPlayback), findsOneWidget);

    await tester.tap(iconButton(AuraStrings.closePlayer));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(find.byType(MiniPlayerBar), findsOneWidget);
    await player.dispose();
  });

  testWidgets('a player with real audio shows no silent label', (tester) async {
    final player = await pumpWithPlayer(tester, isSilent: false);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    expect(find.text(AuraStrings.silentPlayback), findsNothing);
    await player.dispose();
  });

  testWidgets('artwork Hero links the mini player and Now Playing', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    final heroes = tester.widgetList<Hero>(
      find.byWidgetPredicate(
        (w) => w is Hero && w.tag == playerArtworkHeroTag,
        skipOffstage: false,
      ),
    );
    expect(heroes, hasLength(2));
    await player.dispose();
  });

  testWidgets('play/pause toggles playback and its spoken label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);
    final button = inNowPlaying(find.byType(PlayPauseButton));

    expect(tester.getSemantics(button), isSemantics(label: AuraStrings.play));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 200));
    expect(player.snapshot.isPlaying, isTrue);
    expect(tester.getSemantics(button), isSemantics(label: AuraStrings.pause));

    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 200));
    expect(player.snapshot.isPlaying, isFalse);
    handle.dispose();
    await player.dispose();
  });

  testWidgets('next and previous change the track on screen', (tester) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    await tester.tap(inNowPlaying(iconButton(AuraStrings.nextTrack)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(inNowPlaying(find.text(hits[1].title)), findsOneWidget);

    await tester.tap(inNowPlaying(iconButton(AuraStrings.previousTrack)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(inNowPlaying(find.text(hits[0].title)), findsOneWidget);
    await player.dispose();
  });

  testWidgets('next is disabled on the last track until repeat is on', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player, startIndex: hits.length - 1);
    await openNowPlaying(tester);
    final next = inNowPlaying(iconButton(AuraStrings.nextTrack));

    expect(tester.widget<AuraIconButton>(next).onPressed, isNull);
    await tester.tap(toggle((t) => t.semanticLabel == AuraStrings.repeatOff));
    await tester.pump();
    expect(player.snapshot.repeatMode, PlaybackRepeatMode.all);
    expect(tester.widget<AuraIconButton>(next).onPressed, isNotNull);
    await player.dispose();
  });

  testWidgets('repeat cycles off → all → one → off and says so', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    for (final (label, expected) in [
      (AuraStrings.repeatOff, PlaybackRepeatMode.all),
      (AuraStrings.repeatAll, PlaybackRepeatMode.one),
      (AuraStrings.repeatOne, PlaybackRepeatMode.off),
    ]) {
      await tester.tap(toggle((t) => t.semanticLabel == label));
      await tester.pump();
      expect(player.snapshot.repeatMode, expected);
    }
    await player.dispose();
  });

  testWidgets('shuffle turns on, keeps the track, and is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player, startIndex: 3);
    await openNowPlaying(tester);

    final shuffle = toggle((t) => t.semanticLabel == AuraStrings.shuffle);
    await tester.tap(shuffle);
    await tester.pump();

    expect(player.snapshot.shuffleEnabled, isTrue);
    expect(player.snapshot.currentTrack, hits[3]);
    expect(
      tester.getSemantics(shuffle),
      isSemantics(hasToggledState: true, isToggled: true),
    );
    handle.dispose();
    await player.dispose();
  });

  testWidgets('progress shows elapsed and remaining time while playing', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    await player.play();
    await tester.pump(const Duration(seconds: 2));
    await player.pause();
    await tester.pump();

    // Demo tones are 0:12 long.
    expect(inNowPlaying(find.text('0:02')), findsOneWidget);
    expect(inNowPlaying(find.text('-0:10')), findsOneWidget);
    await player.dispose();
  });

  testWidgets('dragging the progress bar seeks', (tester) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    final bar = tester.getRect(
      find.descendant(
        of: find.byType(AuraProgressBar),
        matching: find.byType(CustomPaint),
      ),
    );
    await tester.dragFrom(
      bar.centerLeft + const Offset(2, 0),
      Offset(bar.width / 2, 0),
    );
    await tester.pump();

    final expected = hits.first.duration!.inMilliseconds / 2;
    expect(
      player.position.inMilliseconds,
      closeTo(expected, hits.first.duration!.inMilliseconds * 0.05),
    );
    await player.dispose();
  });

  testWidgets('VoiceOver can seek with increase and decrease', (tester) async {
    final handle = tester.ensureSemantics();
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    final node = tester.getSemantics(
      find.bySemanticsLabel(AuraStrings.playbackPosition),
    );
    expect(node.value, '0:00 из 0:12');

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(player.position, const Duration(seconds: 10));

    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pump();
    expect(player.position, Duration.zero);
    handle.dispose();
    await player.dispose();
  });

  testWidgets('"Далее" names the next track and opens the queue', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    final pill = find.bySemanticsLabel(AuraStrings.upNextTrack(hits[1].title));
    expect(pill, findsOneWidget);
    await tester.tap(pill);
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.byType(QueueScreen), findsOneWidget);
    await player.dispose();
  });

  testWidgets('a swipe on the cover changes the track', (tester) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);
    final cover = inNowPlaying(find.byType(AuraArtwork));

    await tester.fling(cover, const Offset(-200, 0), 1000);
    await tester.pump();
    expect(player.snapshot.currentTrack, hits[1]);
    // Let the cover cross-fade finish, so only one cover is left.
    await tester.pump(sheetTime);

    await tester.fling(cover, const Offset(200, 0), 1000);
    await tester.pump();
    expect(player.snapshot.currentTrack, hits[0]);
    await tester.pump(sheetTime);

    // A slow drag: a short one springs back, a long one changes the track.
    final width = tester.getSize(cover).width;
    await tester.timedDrag(
      cover,
      Offset(-width * 0.1, 0),
      const Duration(seconds: 1),
    );
    await tester.pump(sheetTime);
    expect(player.snapshot.currentTrack, hits[0]);
    await tester.timedDrag(
      cover,
      Offset(-width * 0.6, 0),
      const Duration(seconds: 2),
    );
    await tester.pump();
    expect(player.snapshot.currentTrack, hits[1]);
    await tester.pump(sheetTime);
    await player.dispose();
  });

  testWidgets('the cover eases back while paused', (tester) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);
    double scale() => tester
        .widget<AnimatedScale>(
          find.ancestor(
            of: inNowPlaying(find.byType(AuraArtwork)),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    expect(scale(), lessThan(1));
    await player.play();
    await tester.pump();
    expect(scale(), 1);
    await player.pause();
    await tester.pump(sheetTime);
    await player.dispose();
  });

  testWidgets('queue: clear what is left; recent plays on their own tab', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);
    await tester.tap(iconButton(AuraStrings.queue));
    await tester.pump();
    await tester.pump(sheetTime);

    expect(find.byType(AuraEqualizer), findsOneWidget);
    await tester.tap(find.text(AuraStrings.clear));
    await tester.pump();
    await tester.pump();
    expect(player.snapshot.queue, [hits[0]]);
    expect(find.text(AuraStrings.queueEnd), findsOneWidget);

    await tester.tap(find.text(AuraStrings.queueRecent));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.text(AuraStrings.historyEmptyTitle), findsOneWidget);
    expect(find.text(AuraStrings.nowPlaying), findsNothing);

    await tester.tap(find.text(AuraStrings.queueCurrent));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.text(AuraStrings.nowPlaying), findsOneWidget);
    await player.dispose();
  });

  testWidgets('sleep timer from the player: pause when the track ends', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await player.play();
    await tester.pump();
    await openNowPlaying(tester);

    await tester.tap(
      iconButton('${AuraStrings.sleepTimer}: ${AuraStrings.sleepOff}'),
    );
    await tester.pump();
    await tester.pump(sheetTime);
    await tester.tap(find.text(AuraStrings.sleepAfterTrack));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(
      iconButton('${AuraStrings.sleepTimer}: ${AuraStrings.sleepAfterTrack}'),
      findsOneWidget,
    );

    await player.skipToNext();
    await tester.pump();
    await tester.pump();
    expect(player.snapshot.playWhenReady, isFalse);
    expect(
      iconButton('${AuraStrings.sleepTimer}: ${AuraStrings.sleepOff}'),
      findsOneWidget,
    );
    await tester.pump(sheetTime);
    await player.dispose();
  });

  testWidgets('queue lists now playing and up next; a tap jumps', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    await tester.tap(iconButton(AuraStrings.queue));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.byType(QueueScreen), findsOneWidget);
    expect(find.text(AuraStrings.nowPlaying), findsOneWidget);
    expect(find.text(AuraStrings.upNext), findsOneWidget);

    await tester.tap(find.text(hits[2].title));
    await tester.pump();
    expect(player.snapshot.currentTrack, hits[2]);

    await tester.tap(iconButton(AuraStrings.back));
    await tester.pump();
    await tester.pump(sheetTime);
    expect(inNowPlaying(find.text(hits[2].title)), findsOneWidget);
    await player.dispose();
  });

  testWidgets('swipe down closes Now Playing; a short drag snaps back', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    await tester.drag(find.byType(NowPlayingScreen), const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NowPlayingScreen), findsOneWidget);

    await tester.fling(
      find.byType(NowPlayingScreen),
      const Offset(0, 400),
      1500,
    );
    await tester.pump();
    await tester.pump(sheetTime);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await player.dispose();
  });

  testWidgets('opening slides up normally', (tester) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);

    await tester.tap(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(AuraArtwork),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.ancestor(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(SlideTransition),
      ),
      findsWidgets,
    );
    await tester.pump(sheetTime);
    await player.dispose();
  });

  testWidgets('Reduce Motion: fade instead of slide, no Hero flight', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);

    await tester.tap(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(AuraArtwork),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.ancestor(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    final heroModes = tester.widgetList<HeroMode>(
      find.byType(HeroMode, skipOffstage: false),
    );
    expect(heroModes.every((m) => !m.enabled), isTrue);
    await tester.pump(sheetTime);
    await player.dispose();
  });

  testWidgets('nothing playing: the player shows an empty state', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    ProviderScope.containerOf(tester.element(find.byType(AuraApp)))
        .read(routerProvider)
        .go(AppRoutes.nowPlaying);
    await tester.pump();
    await tester.pump(sheetTime);

    expect(find.text(AuraStrings.nothingPlayingTitle), findsOneWidget);
    await tester.tap(iconButton(AuraStrings.closePlayer));
    await tester.pumpAndSettle();
    expect(find.text('Доброе утро'), findsOneWidget);
    await player.dispose();
  });

  testWidgets('a playback failure is shown without technical details', (
    tester,
  ) async {
    final fake = FakePlaybackController(
      PlaybackSnapshot(
        queue: hits,
        currentIndex: 0,
        failure: const PlaybackFailure(debugMessage: 'codec 0xBAD'),
      ),
    );
    await pumpAuraApp(
      tester,
      overrides: [playbackControllerProvider.overrideWithValue(fake)],
    );
    await openNowPlaying(tester);

    expect(find.text(AuraStrings.failurePlaybackTitle), findsOneWidget);
    expect(find.textContaining('codec'), findsNothing);
  });

  testWidgets('rapid taps on play/pause and next stay consistent', (
    tester,
  ) async {
    final player = await pumpWithPlayer(tester);
    await loadHits(tester, player);
    await openNowPlaying(tester);

    for (var i = 0; i < 21; i++) {
      await tester.tap(inNowPlaying(find.byType(PlayPauseButton)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(player.snapshot.isPlaying, isTrue);

    for (var i = 0; i < 30; i++) {
      await tester.tap(
        inNowPlaying(iconButton(AuraStrings.nextTrack)),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(player.snapshot.currentTrack, hits.last);
    expect(tester.takeException(), isNull);
    await player.dispose();
  });
}
