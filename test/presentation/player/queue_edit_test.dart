import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/player/queue_screen.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

final _tones = DemoCatalog.tones;

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == label,
);

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AuraTabBar)));

void main() {
  group('queue screen', () {
    late EnginePlaybackController player;

    Future<void> openQueue(WidgetTester tester) async {
      player = EnginePlaybackController(
        engine: SimulatedAudioEngine(),
        random: Random(1),
      );
      addTearDown(player.dispose);
      await pumpAuraApp(
        tester,
        overrides: [playbackControllerProvider.overrideWithValue(player)],
      );
      await player.setQueue(_tones);
      await tester.pump();
      unawaited(_router(tester).push(AppRoutes.queue));
      await tester.pumpAndSettle();
      expect(find.byType(QueueScreen), findsOneWidget);
    }

    List<String> queue() => player.snapshot.queue.map((t) => t.title).toList();

    testWidgets('a track can be removed from what plays next', (tester) async {
      await openQueue(tester);
      final second = _tones[2].title;
      await tester.tap(_button('${AuraStrings.removeFromQueue}: $second'));
      await tester.pumpAndSettle();

      expect(queue(), isNot(contains(second)));
      expect(queue(), hasLength(_tones.length - 1));
      expect(find.text(second), findsNothing);
    });

    testWidgets('dragging the handle reorders the queue', (tester) async {
      await openQueue(tester);
      final first = _tones[1].title;
      final handle = find.descendant(
        of: find
            .ancestor(of: find.text(first), matching: find.byType(Semantics))
            .first,
        matching: find.byType(ReorderableDragStartListener),
      );
      await tester.drag(handle.first, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(queue().first, _tones.first.title);
      expect(queue().indexOf(first), greaterThan(1));
    });

    testWidgets('VoiceOver can move tracks without dragging', (tester) async {
      final handle = tester.ensureSemantics();
      await openQueue(tester);
      final first = _tones[1].title;
      final reorder = find.bySemanticsLabel(
        '${AuraStrings.reorderInQueue}: $first',
      );
      expect(
        tester.getSemantics(reorder),
        isSemantics(
          customActions: const [
            CustomSemanticsAction(label: AuraStrings.moveDown),
          ],
        ),
      );

      // Performing "move down" swaps it with the next track.
      tester.semantics.customAction(
        find.semantics.byLabel('${AuraStrings.reorderInQueue}: $first'),
        const CustomSemanticsAction(label: AuraStrings.moveDown),
      );
      await tester.pumpAndSettle();
      expect(queue().indexOf(first), 2);
      handle.dispose();
    });
  });

  testWidgets('a failed track offers a retry in Now Playing', (tester) async {
    final fake = FakePlaybackController(
      PlaybackSnapshot(
        queue: [_tones.first],
        currentIndex: 0,
        status: PlaybackStatus.failed,
        failure: const TimeoutFailure(),
      ),
    );
    await pumpAuraApp(
      tester,
      overrides: [playbackControllerProvider.overrideWithValue(fake)],
    );
    unawaited(_router(tester).push(AppRoutes.nowPlaying));
    await tester.pumpAndSettle();

    expect(find.text(AuraStrings.failureTimeoutTitle), findsOneWidget);
    expect(find.text(AuraStrings.failureTimeoutMessage), findsOneWidget);
    await tester.tap(find.text(AuraStrings.retry));
    await tester.pump();
    expect(fake.playCalls, 1);
  });

  testWidgets('track menus can queue a track next or last', (tester) async {
    final fake = FakePlaybackController(PlaybackSnapshot.initial);
    final library = InMemoryLibraryRepository();
    await library.addTracks([_tones.first]);
    await pumpAuraApp(
      tester,
      library: library,
      overrides: [playbackControllerProvider.overrideWithValue(fake)],
    );
    _router(tester).go(AppRoutes.libraryTracks);
    await tester.pumpAndSettle();

    final title = _tones.first.title;
    for (final action in [AuraStrings.playNext, AuraStrings.playLast]) {
      await tester.tap(_button('${AuraStrings.more}: $title'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoActionSheet),
          matching: find.text(action),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(fake.queueEdits, ['next:$title', 'add:$title']);
  });
}
