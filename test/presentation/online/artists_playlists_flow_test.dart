import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/library_home_feed_source.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/online/online_artist_screen.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fake_providers.dart';
import '../../helpers/fakes.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

void main() {
  late FakeArtistCatalog catalog;
  late FakeLinkOpener links;
  late FakeLinkSharer sharer;
  late FakePlaybackController player;
  late InMemoryLibraryRepository library;

  setUp(() {
    catalog = FakeArtistCatalog(
      search: (query, page) async =>
          Ok(ProviderPage(items: [artistTrack('s1'), artistTrack('s2')])),
    );
    links = FakeLinkOpener();
    sharer = FakeLinkSharer();
    player = FakePlaybackController(PlaybackSnapshot.initial);
  });

  Future<void> pump(
    WidgetTester tester, {
    TestDevice device = iPhone15,
    double textScale = 1,
  }) async {
    library = InMemoryLibraryRepository();
    await pumpAuraApp(
      tester,
      device: device,
      textScale: textScale,
      library: library,
      homeFeedSource: LibraryHomeFeedSource(repository: library),
      overrides: [
        providerRegistryProvider.overrideWithValue(ProviderRegistry([catalog])),
        externalLinkOpenerProvider.overrideWithValue(links),
        linkSharerProvider.overrideWithValue(sharer),
        playbackControllerProvider.overrideWithValue(player),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Searches, then opens the menu of the first result.
  Future<void> openMenuOfFirstResult(WidgetTester tester) async {
    await tester.tap(tab(AuraStrings.tabSearch));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'x');
    await tester.pump(SearchQueryController.debounce);
    await tester.pumpAndSettle();
    await tester.tap(iconButton('${AuraStrings.more}: Track s1'));
    await tester.pumpAndSettle();
  }

  group('artist page', () {
    testWidgets('from a track menu: who, tracks, play, the catalog page', (
      tester,
    ) async {
      await pump(tester);
      await openMenuOfFirstResult(tester);
      await tester.tap(find.text(AuraStrings.goToArtist));
      await tester.pumpAndSettle();

      expect(find.byType(OnlineArtistScreen), findsOneWidget);
      expect(find.text('Artist a1'), findsOneWidget);
      expect(find.text(AuraStrings.followers(1200)), findsOneWidget);
      expect(find.text('Track a1-1'), findsOneWidget);

      await tester.tap(find.text(AuraStrings.playAll));
      await tester.pumpAndSettle();
      expect(player.lastQueue!.map((t) => t.title), [
        'Track a1-1',
        'Track a1-2',
      ]);

      await tester.tap(find.text(AuraStrings.openAt('Каталог')));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://catalog.test/artist/a1')]);
    });

    for (final device in [iPhoneSE, iPhone15Landscape]) {
      testWidgets('$device, largest text: the artist page lays out', (
        tester,
      ) async {
        await pump(tester, device: device, textScale: 3);
        unawaited(
          GoRouter.of(tester.element(find.byType(AuraTabBar)))
              .push(AppRoutes.onlineArtist(AppRoutes.home, 'catalog', 'a1')),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a failure offers a retry', (tester) async {
      catalog.artistAnswer = (_) async => const Err(NetworkFailure());
      await pump(tester);
      unawaited(
        GoRouter.of(tester.element(find.byType(AuraTabBar)))
            .push(AppRoutes.onlineArtist(AppRoutes.home, 'catalog', 'a1')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.failureNetworkTitle), findsOneWidget);

      catalog.artistAnswer = FakeArtistCatalog().artistAnswer;
      await tester.tap(find.text(AuraStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Artist a1'), findsOneWidget);
    });
  });

  testWidgets('the artist name in Now Playing opens the artist page', (
    tester,
  ) async {
    player = FakePlaybackController(
      PlaybackSnapshot(
        queue: [artistTrack('n1')],
        currentIndex: 0,
        status: PlaybackStatus.playing,
      ),
    );
    await pump(tester);
    unawaited(
      GoRouter.of(tester.element(find.byType(AuraTabBar)))
          .push(AppRoutes.nowPlaying),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(AuraStrings.openArtist('Artist a1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnlineArtistScreen), findsOneWidget);
    expect(find.text(AuraStrings.followers(1200)), findsOneWidget);
  });

  testWidgets('an online track goes into a new playlist and out again', (
    tester,
  ) async {
    await pump(tester);
    await openMenuOfFirstResult(tester);
    await tester.tap(find.text(AuraStrings.addToPlaylist));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuraStrings.newPlaylist));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Онлайн');
    await tester.tap(find.text(AuraStrings.create));
    await tester.pumpAndSettle();

    final playlist = library.current.playlists.single;
    expect(playlist.trackIds, [const TrackId('catalog:s1')]);

    GoRouter.of(tester.element(find.byType(AuraTabBar))).go(
      AppRoutes.detail(
        AppRoutes.library,
        DetailKind.playlist,
        playlist.id.value,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Track s1'), findsOneWidget);
    expect(find.text(AuraStrings.trackCount(1)), findsOneWidget);

    await tester.tap(iconButton('${AuraStrings.more}: Track s1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuraStrings.removeFromPlaylist));
    await tester.pumpAndSettle();
    expect(library.current.playlists.single.trackIds, isEmpty);
  });

  testWidgets('radio and share from the track menu', (tester) async {
    await pump(tester);
    await openMenuOfFirstResult(tester);
    await tester.tap(find.text(AuraStrings.startRadio));
    await tester.pumpAndSettle();
    expect(catalog.radioSeeds.single.title, 'Track s1');
    expect(player.lastQueue!.first.title, 'Track s1');
    expect(player.lastQueue, hasLength(6));

    await tester.tap(iconButton('${AuraStrings.more}: Track s1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuraStrings.share));
    await tester.pumpAndSettle();
    expect(sharer.shared.single, (
      'Track s1 — Artist a1',
      Uri.parse('https://catalog.test/track/s1'),
    ));
  });

  testWidgets('the queue is saved as a playlist, online tracks included', (
    tester,
  ) async {
    player = FakePlaybackController(
      PlaybackSnapshot(
        queue: [artistTrack('q1'), artistTrack('q2')],
        currentIndex: 0,
        status: PlaybackStatus.paused,
      ),
    );
    await pump(tester);
    unawaited(
      GoRouter.of(tester.element(find.byType(AuraTabBar)))
          .push(AppRoutes.queue),
    );
    await tester.pumpAndSettle();

    await tester.tap(iconButton(AuraStrings.saveQueueAsPlaylist));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuraStrings.newPlaylist));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Вечер');
    await tester.tap(find.text(AuraStrings.create));
    await tester.pumpAndSettle();

    expect(find.text(AuraStrings.savedToPlaylist(2)), findsOneWidget);
    expect(library.current.playlists.single.trackIds, [
      const TrackId('catalog:q1'),
      const TrackId('catalog:q2'),
    ]);
  });
}
