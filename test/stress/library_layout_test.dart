import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/domain/library/library_keys.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

import '../helpers/aura_app_harness.dart';

const _long =
    'Очень длинное название, которое не поместится ни в одну строку экрана';

Track _track(int i) => Track(
  id: TrackId('t$i'),
  title: i == 0 ? _long : 'Трек $i',
  artistName: i.isEven ? 'Исполнитель с длинным именем $i' : null,
  albumTitle: i % 3 == 0 ? '$_long (альбом)' : null,
  trackNumber: i,
  duration: Duration(seconds: 61 * i + 5),
  addedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
  sources: [LocalFileSource('library:audio/$i.mp3')],
);

Future<(InMemoryLibraryRepository, PlaylistId)> _library() async {
  final library = InMemoryLibraryRepository();
  final tracks = [for (var i = 0; i < 40; i++) _track(i)];
  await library.addTracks(tracks);
  await library.setFavorite(tracks.first.id, favorite: true);
  final created = await library.createPlaylist('$_long (плейлист)');
  final id = (created as Ok<Playlist>).value.id;
  await library.addToPlaylist(id, [for (final t in tracks.take(5)) t.id]);
  return (library, id);
}

Future<void> _visit(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(AuraTabBar))).go(location);
  await tester.pumpAndSettle();
  // Scroll to the end: every row is built and laid out once.
  final scrollable = find.byType(Scrollable).hitTestable();
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -20000));
    await tester.pumpAndSettle();
  }
}

/// Every library page on every device and text size. Any overflow or
/// exception fails the test.
void main() {
  for (final device in allDevices) {
    for (final scale in allTextScales) {
      testWidgets('$device, text ×$scale: library pages lay out', (
        tester,
      ) async {
        final (library, playlistId) = await _library();
        await pumpAuraApp(
          tester,
          library: library,
          device: device,
          textScale: scale,
        );
        final album = albumKeyOf(_track(0))!;
        final artist = artistKeyOf(_track(0))!;

        for (final location in [
          AppRoutes.library,
          AppRoutes.libraryTracks,
          AppRoutes.libraryFavorites,
          AppRoutes.libraryAlbums,
          AppRoutes.libraryArtists,
          AppRoutes.libraryPlaylists,
          AppRoutes.detail(AppRoutes.library, DetailKind.album, album.value),
          AppRoutes.detail(AppRoutes.library, DetailKind.artist, artist.value),
          AppRoutes.detail(
            AppRoutes.library,
            DetailKind.playlist,
            playlistId.value,
          ),
          AppRoutes.detail(AppRoutes.library, DetailKind.playlist, 'missing'),
        ]) {
          await _visit(tester, location);
        }

        await _visit(tester, AppRoutes.search);
        await tester.enterText(find.byType(CupertinoSearchTextField), 'трек');
        await tester.pump(SearchQueryController.debounce);
        await tester.pumpAndSettle();
        expect(find.text(AuraStrings.searchSectionTracks), findsOneWidget);
      });
    }
  }

  for (final device in [iPhone15, iPhone15Landscape, iPadMini]) {
    testWidgets('$device: album artwork and title are centered', (
      tester,
    ) async {
      // A short title: the header must not shrink to its widest line.
      final track = Track(
        id: const TrackId('short'),
        title: 'Трек',
        albumTitle: 'Альбом',
        sources: const [LocalFileSource('library:audio/short.mp3')],
      );
      final library = InMemoryLibraryRepository();
      await library.addTracks([track]);
      await pumpAuraApp(tester, library: library, device: device);
      final album = albumKeyOf(track)!;
      GoRouter.of(
        tester.element(find.byType(AuraTabBar)),
      ).go(AppRoutes.detail(AppRoutes.library, DetailKind.album, album.value));
      await tester.pumpAndSettle();

      final page = tester.getRect(find.byType(CustomScrollView));
      final artwork = tester.getRect(
        find.byWidgetPredicate((w) => w is AuraArtwork && w.size == 200),
      );
      expect(artwork.center.dx, moreOrLessEquals(page.center.dx, epsilon: 1));
    });
  }

  for (final location in [
    AppRoutes.library,
    AppRoutes.libraryTracks,
    AppRoutes.libraryPlaylists,
  ]) {
    testWidgets('$location: 44pt targets, labels, rendered contrast', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final (library, _) = await _library();
      await pumpAuraApp(tester, library: library);
      GoRouter.of(tester.element(find.byType(AuraTabBar))).go(location);
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // See accessibility_test.dart for why Linux skips the pixel check.
      if (!Platform.isLinux) {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  }
}
