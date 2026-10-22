import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';
import 'package:music_app/presentation/player/play_pause_button.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

void main() {
  final track = Track(
    id: const TrackId('t1'),
    title: 'Тестовый трек',
    sources: const [LocalFileSource('t1.mp3')],
  );

  PlaybackSnapshot snapshot(PlaybackStatus status) =>
      PlaybackSnapshot(queue: [track], currentIndex: 0, status: status);

  testWidgets('hidden while there is no player', (tester) async {
    await pumpAuraApp(tester);

    expect(find.byType(MiniPlayerBar), findsNothing);
  });

  testWidgets('shows the current track and sends play/pause commands', (
    tester,
  ) async {
    final controller = FakePlaybackController(snapshot(PlaybackStatus.paused));
    await pumpAuraApp(
      tester,
      overrides: [playbackControllerProvider.overrideWithValue(controller)],
    );

    expect(find.text('Тестовый трек'), findsOneWidget);
    expect(find.text(AuraStrings.unknownArtist), findsOneWidget);

    await tester.tap(find.byType(PlayPauseButton));
    expect(controller.playCalls, 1);

    controller.emit(snapshot(PlaybackStatus.playing));
    await tester.pump();
    await tester.tap(find.byType(PlayPauseButton));
    expect(controller.pauseCalls, 1);
  });

  testWidgets('"next" is disabled on the last track without repeat', (
    tester,
  ) async {
    final controller = FakePlaybackController(snapshot(PlaybackStatus.paused));
    final handle = tester.ensureSemantics();
    await pumpAuraApp(
      tester,
      overrides: [playbackControllerProvider.overrideWithValue(controller)],
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel(AuraStrings.nextTrack)),
      isSemantics(isButton: true, isEnabled: false),
    );
    handle.dispose();
  });
}
