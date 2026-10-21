import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/home/home_screen.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';

import '../helpers/aura_app_harness.dart';
import '../helpers/fakes.dart';

Finder tabLabel(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

/// Every device × every iOS text size, with the mini player showing a very
/// long title. Any overflow or exception fails the test.
void main() {
  final longTrack = Track(
    id: const TrackId('long'),
    title:
        'Очень длинное название трека, которое точно не поместится '
        'в одну строку мини-плеера',
    artistName: 'Исполнитель с очень длинным именем для проверки обрезки',
    sources: const [LocalFileSource('long.mp3')],
  );

  for (final device in allDevices) {
    for (final scale in allTextScales) {
      testWidgets('$device, text ×$scale: tabs lay out within safe areas', (
        tester,
      ) async {
        final controller = FakePlaybackController(
          PlaybackSnapshot(
            queue: [longTrack],
            currentIndex: 0,
            status: PlaybackStatus.playing,
          ),
        );
        await pumpAuraApp(
          tester,
          device: device,
          textScale: scale,
          overrides: [playbackControllerProvider.overrideWithValue(controller)],
        );
        final insets = device.padding;
        final screen = device.size;

        // Content starts below the status bar / Dynamic Island and clear of
        // landscape side insets.
        final greeting = tester.getTopLeft(find.text('Доброе утро'));
        expect(greeting.dy, greaterThanOrEqualTo(insets.top));
        expect(greeting.dx, greaterThanOrEqualTo(insets.left));

        // Bottom chrome stays above the home indicator and clear of the
        // side insets.
        expect(
          tester.getBottomLeft(tabLabel('Главная')).dy,
          lessThanOrEqualTo(screen.height - insets.bottom),
        );
        final artwork = find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byType(AuraArtwork),
        );
        expect(
          tester.getTopLeft(artwork).dx,
          greaterThanOrEqualTo(insets.left),
        );
        expect(
          tester.getTopRight(find.byType(MiniPlayerBar)).dx,
          lessThanOrEqualTo(screen.width),
        );

        // Home: scroll through every section to the end.
        final homeScrollable = find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Плейлисты'),
          300,
          scrollable: homeScrollable,
        );
        await tester.drag(homeScrollable, const Offset(0, -3000));
        await tester.pumpAndSettle();

        // Search with a long query.
        await tester.tap(tabLabel('Поиск'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(CupertinoSearchTextField),
          'очень длинный поисковый запрос ' * 4,
        );
        await tester.pump(SearchQueryController.debounce);
        await tester.pumpAndSettle();

        // Library.
        await tester.tap(tabLabel('Библиотека'));
        await tester.pumpAndSettle();
        expect(find.text('Библиотека пуста'), findsOneWidget);
      });
    }
  }
}
