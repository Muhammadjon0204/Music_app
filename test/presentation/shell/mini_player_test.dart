import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

void main() {
  final track = Track(
    id: const TrackId('t1'),
    title: 'Тестовый трек',
    sources: const [LocalFileSource('t1.mp3')],
  );

  testWidgets('hidden while there is no audio engine', (tester) async {
    await pumpAuraApp(tester);

    expect(find.byType(MiniPlayerBar), findsNothing);
  });

  testWidgets('shows the current track and sends play/pause commands', (
    tester,
  ) async {
    final controller = FakePlaybackController(
      PlaybackSnapshot(
        queue: [track],
        currentIndex: 0,
        status: PlaybackStatus.paused,
      ),
    );
    await pumpAuraApp(
      tester,
      overrides: [playbackControllerProvider.overrideWithValue(controller)],
    );

    expect(find.text('Тестовый трек'), findsOneWidget);
    expect(find.text(AuraStrings.unknownArtist), findsOneWidget);

    await tester.tap(iconButton(AuraStrings.play));
    expect(controller.playCalls, 1);

    controller.emit(
      PlaybackSnapshot(
        queue: [track],
        currentIndex: 0,
        status: PlaybackStatus.playing,
      ),
    );
    await tester.pump();
    await tester.tap(iconButton(AuraStrings.pause));
    expect(controller.pauseCalls, 1);
  });
}
