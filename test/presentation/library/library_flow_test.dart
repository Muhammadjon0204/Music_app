import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/library_home_feed_source.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/library/library_keys.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_track_tile.dart';
import 'package:music_app/presentation/library/track_collection_screens.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/player/now_playing_screen.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

Track track(
  String id,
  String title, {
  String? artist,
  String? album,
  int? number,
  int day = 1,
}) => Track(
  id: TrackId(id),
  title: title,
  artistName: artist,
  albumTitle: album,
  trackNumber: number,
  duration: const Duration(minutes: 3, seconds: 5),
  addedAt: DateTime(2026, 1, day),
  sources: [LocalFileSource('library:audio/$id.mp3')],
);

final sample = [
  track('a', 'Звезда', artist: 'Кино', album: 'Группа крови', number: 2),
  track('b', 'Группа крови', artist: 'Кино', album: 'Группа крови', number: 1),
  track('c', 'Ночь', artist: 'Ария', day: 3),
  track('d', 'Без тегов', day: 2),
];

Future<InMemoryLibraryRepository> libraryWith(List<Track> tracks) async {
  final library = InMemoryLibraryRepository();
  await library.addTracks(tracks);
  return library;
}

List<String> visibleTrackTitles(WidgetTester tester) => tester
    .widgetList<LibraryTrackTile>(find.byType(LibraryTrackTile))
    .map((t) => t.track.title)
    .toList();

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(AuraTabBar)));

Future<void> openLibraryTab(WidgetTester tester) async {
  await tester.tap(tab(AuraStrings.tabLibrary));
  await tester.pumpAndSettle();
}

Future<void> openCategory(WidgetTester tester, String title) async {
  await openLibraryTab(tester);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> chooseInSheet(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoActionSheet),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapDialogAction(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> typeInDialog(WidgetTester tester, String text) => tester.enterText(
  find.descendant(
    of: find.byType(CupertinoAlertDialog),
    matching: find.byType(CupertinoTextField),
  ),
  text,
);

class FakePicker implements AudioFilePicker {
  FakePicker(this.files);

  final List<PickedAudioFile> files;
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<List<PickedAudioFile>> pick() async {
    calls++;
    return files;
  }
}

class FakeImporter implements TrackImporter {
  FakeImporter(this.report);

  final ImportReport report;
  final release = Completer<void>();

  @override
  Future<ImportReport> importFiles(
    List<PickedAudioFile> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    onProgress?.call(1, files.length);
    await release.future;
    return report;
  }
}

class FakeMissing implements MissingFileChecker {
  FakeMissing(this.missing);

  final Set<TrackId> missing;

  @override
  Future<Set<TrackId>> findMissing(List<Track> tracks) async => missing;
}

void main() {
  group('empty library', () {
    testWidgets('without import (web) offers the demo tracks', (tester) async {
      final library = InMemoryLibraryRepository();
      await pumpAuraApp(
        tester,
        library: library,
        overrides: [
          demoTracksProvider.overrideWithValue([track('demo', 'Демо-тон')]),
        ],
      );
      await openLibraryTab(tester);

      expect(find.text(AuraStrings.libraryEmptyTitle), findsOneWidget);
      expect(
        find.text(AuraStrings.libraryEmptyMessageNoImport),
        findsOneWidget,
      );
      expect(find.text(AuraStrings.importMusic), findsNothing);

      await tester.tap(find.text(AuraStrings.addDemoTracks));
      await tester.pumpAndSettle();

      expect(library.current.tracks.single.title, 'Демо-тон');
      expect(find.text(AuraStrings.favorites), findsOneWidget);
      expect(find.text(AuraStrings.allTracks), findsOneWidget);
      expect(find.text('Демо-тон'), findsOneWidget);
    });

    testWidgets('import shows progress, then a report the user can close', (
      tester,
    ) async {
      final picker = FakePicker(const [
        PickedAudioFile(path: '/tmp/1.mp3', name: '1.mp3'),
        PickedAudioFile(path: '/tmp/2.mp3', name: '2.mp3'),
        PickedAudioFile(path: '/tmp/3.txt', name: '3.txt'),
      ]);
      final importer = FakeImporter(
        ImportReport(
          imported: [sample[0], sample[1]],
          skipped: const {
            '3.txt': ImportSkipReason.unsupported,
            '4.mp3': ImportSkipReason.duplicate,
          },
        ),
      );
      var cleared = 0;
      await pumpAuraApp(
        tester,
        overrides: [
          audioFilePickerProvider.overrideWithValue(picker),
          trackImporterProvider.overrideWithValue(importer),
          clearPickedFilesProvider.overrideWithValue(() async => cleared++),
        ],
      );
      await openLibraryTab(tester);

      expect(find.text(AuraStrings.libraryEmptyMessage), findsOneWidget);
      await tester.tap(find.text(AuraStrings.importMusic));
      await tester.pump();
      await tester.pump();
      expect(find.text(AuraStrings.importProgress(1, 3)), findsOneWidget);

      importer.release.complete();
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(cleared, 1);
      expect(find.text('Добавлено: 2 трека'), findsOneWidget);
      expect(find.text('Уже были в библиотеке: 1 трек'), findsOneWidget);
      expect(find.text('Не удалось добавить: 1 файл'), findsOneWidget);

      await tester.tap(iconButton(AuraStrings.dismiss));
      await tester.pumpAndSettle();
      expect(find.textContaining('Добавлено'), findsNothing);
    });

    testWidgets('storage failure is explained without technical details', (
      tester,
    ) async {
      await pumpAuraApp(
        tester,
        overrides: [
          libraryStorageFailureProvider.overrideWithValue(
            const StorageFailure(debugMessage: 'db locked'),
          ),
        ],
      );
      await openLibraryTab(tester);
      expect(find.text(AuraStrings.libraryStorageWarning), findsOneWidget);
      expect(find.textContaining('db locked'), findsNothing);
    });
  });

  group('library content', () {
    testWidgets('categories show counts and open their lists', (tester) async {
      await pumpAuraApp(tester, library: await libraryWith(sample));
      await openLibraryTab(tester);

      expect(find.text('4 трека'), findsOneWidget);
      expect(find.text('1 альбом'), findsOneWidget);
      expect(find.text('2 исполнителя'), findsOneWidget);
      expect(find.text('0 плейлистов'), findsOneWidget);

      await tester.tap(find.text(AuraStrings.albums));
      await tester.pumpAndSettle();
      // Untagged tracks are not grouped into an album.
      expect(find.text('Группа крови'), findsOneWidget);

      await tester.tap(find.text('Группа крови'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      // Album order: track 1 before track 2.
      expect(visibleTrackTitles(tester), ['Группа крови', 'Звезда']);

      await tester.tap(iconButton(AuraStrings.back));
      await tester.pumpAndSettle();
      await tester.tap(iconButton(AuraStrings.back));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.artists));
      await tester.pumpAndSettle();
      expect(find.text('Ария'), findsOneWidget);
      expect(find.text('Кино'), findsOneWidget);
      await tester.tap(find.text('Кино'));
      await tester.pumpAndSettle();
      expect(find.byType(ArtistScreen), findsOneWidget);
      expect(find.byType(LibraryTrackTile), findsNWidgets(2));
    });

    testWidgets('play and shuffle start the list in the player', (
      tester,
    ) async {
      final controller = FakePlaybackController(PlaybackSnapshot.initial);
      await pumpAuraApp(
        tester,
        library: await libraryWith(sample),
        overrides: [playbackControllerProvider.overrideWithValue(controller)],
      );
      await openCategory(tester, AuraStrings.allTracks);

      // Sorted by title.
      expect(visibleTrackTitles(tester), [
        'Без тегов',
        'Группа крови',
        'Звезда',
        'Ночь',
      ]);
      await tester.tap(find.text('Звезда'));
      await tester.pumpAndSettle();
      expect(controller.lastQueue!.map((t) => t.title), [
        'Без тегов',
        'Группа крови',
        'Звезда',
        'Ночь',
      ]);
      expect(controller.lastStartIndex, 2);
      expect(controller.shuffleEnabled, isFalse);
      expect(controller.playCalls, 1);

      await tester.tap(find.text(AuraStrings.shuffleAll));
      await tester.pumpAndSettle();
      expect(controller.shuffleEnabled, isTrue);
      expect(controller.playCalls, 2);
    });

    testWidgets('sorting reorders the list and marks the choice', (
      tester,
    ) async {
      await pumpAuraApp(tester, library: await libraryWith(sample));
      await openCategory(tester, AuraStrings.allTracks);

      await tester.tap(iconButton(AuraStrings.sortBy));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.sortRecent);
      expect(visibleTrackTitles(tester), [
        'Ночь',
        'Без тегов',
        'Звезда',
        'Группа крови',
      ]);

      await tester.tap(iconButton(AuraStrings.sortBy));
      await tester.pumpAndSettle();
      expect(find.text('${AuraStrings.sortRecent} ✓'), findsOneWidget);
      await chooseInSheet(tester, AuraStrings.sortArtist);
      // Unknown artist sorts last.
      expect(visibleTrackTitles(tester).first, 'Ночь');
      expect(visibleTrackTitles(tester).last, 'Без тегов');
    });

    testWidgets('favorites from the track menu and from Now Playing', (
      tester,
    ) async {
      final library = await libraryWith(sample);
      final controller = FakePlaybackController(
        PlaybackSnapshot(
          queue: [sample[2]],
          currentIndex: 0,
          status: PlaybackStatus.playing,
        ),
      );
      await pumpAuraApp(
        tester,
        library: library,
        overrides: [playbackControllerProvider.overrideWithValue(controller)],
      );
      await openCategory(tester, AuraStrings.allTracks);

      await tester.tap(iconButton('${AuraStrings.more}: Звезда'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.addToFavorites);
      expect(library.current.isFavorite(const TrackId('a')), isTrue);

      await tester.tap(iconButton('${AuraStrings.more}: Звезда'));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.removeFromFavorites), findsOneWidget);
      await chooseInSheet(tester, AuraStrings.cancel);

      unawaited(routerOf(tester).push(AppRoutes.nowPlaying));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      await tester.tap(iconButton(AuraStrings.favoriteTrack));
      await tester.pumpAndSettle();
      expect(library.current.isFavorite(const TrackId('c')), isTrue);
      expect(library.current.favoriteIds.first, const TrackId('c'));
    });

    testWidgets('Now Playing has no heart for tracks outside the library', (
      tester,
    ) async {
      final controller = FakePlaybackController(
        PlaybackSnapshot(
          queue: [track('elsewhere', 'Не из библиотеки')],
          currentIndex: 0,
        ),
      );
      await pumpAuraApp(
        tester,
        overrides: [playbackControllerProvider.overrideWithValue(controller)],
      );
      unawaited(routerOf(tester).push(AppRoutes.nowPlaying));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(iconButton(AuraStrings.favoriteTrack), findsNothing);
    });

    testWidgets('favorites list shows the newest favorite first', (
      tester,
    ) async {
      final library = await libraryWith(sample);
      await library.setFavorite(const TrackId('c'), favorite: true);
      await library.setFavorite(const TrackId('a'), favorite: true);
      await pumpAuraApp(tester, library: library);
      await openCategory(tester, AuraStrings.favorites);

      expect(visibleTrackTitles(tester), ['Звезда', 'Ночь']);
    });

    testWidgets('playlists: create from a track, rename, remove, delete', (
      tester,
    ) async {
      final library = await libraryWith(sample);
      await pumpAuraApp(tester, library: library);
      await openCategory(tester, AuraStrings.allTracks);

      await tester.tap(iconButton('${AuraStrings.more}: Ночь'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.addToPlaylist);
      await chooseInSheet(tester, AuraStrings.newPlaylist);

      // An empty name is rejected with an explanation.
      await tapDialogAction(tester, AuraStrings.create);
      expect(find.text(AuraStrings.playlistNameInvalid), findsOneWidget);
      await typeInDialog(tester, '  Вечер  ');
      await tapDialogAction(tester, AuraStrings.create);

      final playlist = library.current.playlists.single;
      expect(playlist.name, 'Вечер');
      expect(playlist.trackIds, [const TrackId('c')]);

      // Adding to an existing playlist.
      await tester.tap(iconButton('${AuraStrings.more}: Звезда'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.addToPlaylist);
      await chooseInSheet(tester, 'Вечер');
      expect(library.current.playlists.single.trackIds, [
        const TrackId('c'),
        const TrackId('a'),
      ]);

      await tester.tap(iconButton(AuraStrings.back));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.playlists));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Вечер'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistScreen), findsOneWidget);
      expect(find.byType(LibraryTrackTile), findsNWidgets(2));

      await tester.tap(iconButton('${AuraStrings.more}: Ночь'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.removeFromPlaylist);
      expect(library.current.playlists.single.trackIds, [const TrackId('a')]);
      // Still in the library.
      expect(library.current.contains(const TrackId('c')), isTrue);

      await tester.tap(iconButton('${AuraStrings.more}: Вечер'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.rename);
      await typeInDialog(tester, 'Ночь в городе');
      await tapDialogAction(tester, AuraStrings.save);
      expect(library.current.playlists.single.name, 'Ночь в городе');

      await tester.tap(iconButton('${AuraStrings.more}: Ночь в городе'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.deletePlaylist);
      await tapDialogAction(tester, AuraStrings.remove);
      expect(library.current.playlists, isEmpty);
      expect(find.byType(PlaylistScreen), findsNothing);
      expect(find.text(AuraStrings.playlistsEmptyTitle), findsOneWidget);
    });

    testWidgets('removing a track asks first', (tester) async {
      final library = await libraryWith(sample);
      await pumpAuraApp(tester, library: library);
      await openCategory(tester, AuraStrings.allTracks);

      await tester.tap(iconButton('${AuraStrings.more}: Ночь'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.removeFromLibrary);
      expect(find.text(AuraStrings.removeFromLibraryConfirm), findsOneWidget);
      await tapDialogAction(tester, AuraStrings.cancel);
      expect(library.current.contains(const TrackId('c')), isTrue);

      await tester.tap(iconButton('${AuraStrings.more}: Ночь'));
      await tester.pumpAndSettle();
      await chooseInSheet(tester, AuraStrings.removeFromLibrary);
      await tapDialogAction(tester, AuraStrings.remove);
      expect(library.current.contains(const TrackId('c')), isFalse);
      expect(find.text('Ночь'), findsNothing);
    });

    testWidgets('a missing file is labeled, skipped and can be removed', (
      tester,
    ) async {
      final library = await libraryWith(sample);
      final controller = FakePlaybackController(PlaybackSnapshot.initial);
      await pumpAuraApp(
        tester,
        library: library,
        overrides: [
          playbackControllerProvider.overrideWithValue(controller),
          missingFileCheckerProvider.overrideWithValue(
            FakeMissing({const TrackId('a')}),
          ),
        ],
      );
      await openCategory(tester, AuraStrings.allTracks);

      expect(find.text(AuraStrings.missingFile), findsOneWidget);
      await tester.tap(find.text(AuraStrings.playAll));
      await tester.pumpAndSettle();
      expect(controller.lastQueue, hasLength(3));
      expect(
        controller.lastQueue!.map((t) => t.id),
        isNot(contains(const TrackId('a'))),
      );

      await tester.tap(find.text('Звезда'));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.missingFileMessage), findsOneWidget);
      await tapDialogAction(tester, AuraStrings.removeFromLibrary);
      expect(library.current.contains(const TrackId('a')), isFalse);
    });

    testWidgets('a deleted playlist shows "not found"; back goes to Library', (
      tester,
    ) async {
      await pumpAuraApp(tester, library: await libraryWith(sample));
      routerOf(tester)
          .go(AppRoutes.detail(AppRoutes.library, DetailKind.playlist, 'gone'));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.notFoundTitle), findsOneWidget);

      await tester.tap(iconButton(AuraStrings.back));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.allTracks), findsOneWidget);
    });

    testWidgets('detail ids with special characters survive the URL', (
      tester,
    ) async {
      final odd = track(
        'odd',
        'Трек',
        artist: 'AC/DC 100%',
        album: 'Back / in ? Black #1',
      );
      await pumpAuraApp(tester, library: await libraryWith([odd]));
      routerOf(tester).go(
        AppRoutes.detail(
          AppRoutes.library,
          DetailKind.album,
          albumKeyOf(odd)!.value,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(find.text('Back / in ? Black #1'), findsOneWidget);
      expect(find.text(AuraStrings.notFoundTitle), findsNothing);

      routerOf(tester).go(
        AppRoutes.detail(
          AppRoutes.search,
          DetailKind.artist,
          artistKeyOf(odd)!.value,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArtistScreen), findsOneWidget);
      expect(find.text('AC/DC 100%'), findsOneWidget);
    });
  });

  group('search and home', () {
    testWidgets('search finds tracks, albums and artists', (tester) async {
      await pumpAuraApp(tester, library: await libraryWith(sample));
      await tester.tap(tab(AuraStrings.tabSearch));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.searchHintMessageReady), findsOneWidget);

      // Case and word order do not matter; artist words match tracks.
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'КРОВИ кино',
      );
      await tester.pump(SearchQueryController.debounce);
      await tester.pumpAndSettle();

      expect(find.text(AuraStrings.albums), findsOneWidget);
      expect(find.text(AuraStrings.searchSectionTracks), findsOneWidget);
      expect(find.byType(LibraryTrackTile), findsNWidgets(2));

      // The album row (first match; the track of the same name follows).
      await tester.tap(find.text('Группа крови').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
      // Opened inside the Search tab.
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.path,
        startsWith(AppRoutes.search),
      );

      await tester.tap(iconButton(AuraStrings.back));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
      await tester.pump(SearchQueryController.debounce);
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.searchNoResultsInLibrary), findsOneWidget);
    });

    testWidgets('Home shows the library, not demo data, once it has music', (
      tester,
    ) async {
      final library = await libraryWith(sample);
      await pumpAuraApp(
        tester,
        library: library,
        homeFeedSource: LibraryHomeFeedSource(
          repository: library,
          whenEmpty: const DemoHomeFeedSource(),
        ),
      );

      expect(find.text(AuraStrings.demoBadge), findsNothing);
      expect(find.text(AuraStrings.allTracks), findsOneWidget);
      // A collection, not a playlist.
      expect(find.text('4 трека'), findsOneWidget);
      expect(find.textContaining(AuraStrings.playlist), findsNothing);

      await tester.tap(find.text('Группа крови').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumScreen), findsOneWidget);
    });

    testWidgets('demo Home cards are not tappable', (tester) async {
      await pumpAuraApp(tester);
      final cards = tester.widgetList<AuraMediaCard>(
        find.byType(AuraMediaCard),
      );
      expect(cards, isNotEmpty);
      expect(cards.every((c) => c.onPressed == null), isTrue);
    });
  });
}
