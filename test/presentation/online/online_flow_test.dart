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
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/home/home_screen.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/search/search_screen.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fake_providers.dart';
import '../../helpers/fakes.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

/// A catalog whose terms require naming it, like Jamendo.
class _CreditedCatalog extends FakeCatalogProvider
    implements AttributionRequiredProvider {
  _CreditedCatalog({super.search})
    : super(providerId: const ProviderId('credited'), name: 'Кредит');
}

final _popular = [
  onlineTrack('1'),
  onlineTrack('2', availability: StreamAvailability.externalOnly),
  onlineTrack('3'),
];

void main() {
  late FakeCatalogProvider catalog;
  late FakeLinkOpener links;
  late FakePlaybackController player;
  late InMemoryLibraryRepository library;

  setUp(() {
    catalog = FakeCatalogProvider(
      popular: () async => Ok(ProviderPage(items: _popular)),
      search: (query, page) async => Ok(
        ProviderPage(
          items: [
            for (var i = page.offset; i < page.offset + 2; i++)
              onlineTrack('s$i', title: '$query $i'),
          ],
          nextOffset: page.offset == 0 ? 2 : null,
        ),
      ),
    );
    links = FakeLinkOpener();
    player = FakePlaybackController(PlaybackSnapshot.initial);
  });

  Future<void> pump(
    WidgetTester tester, {
    TestDevice device = iPhone15,
    double textScale = 1,
    List<MusicProvider>? providers,
  }) async {
    library = InMemoryLibraryRepository();
    await pumpAuraApp(
      tester,
      library: library,
      device: device,
      textScale: textScale,
      homeFeedSource: LibraryHomeFeedSource(repository: library),
      overrides: [
        providerRegistryProvider.overrideWithValue(
          ProviderRegistry(providers ?? [catalog]),
        ),
        externalLinkOpenerProvider.overrideWithValue(links),
        playbackControllerProvider.overrideWithValue(player),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('Home', () {
    /// The Home page's own vertical list.
    Finder homeList() => find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    /// [finder] after scrolling Home until it is on screen.
    Future<Finder> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 300, scrollable: homeList());
      await tester.pumpAndSettle();
      return finder;
    }

    Finder card(String title) => find.descendant(
      of: find.byType(AuraMediaCard),
      matching: find.text(title),
    );

    testWidgets('an empty library shows the real catalog and an import hint', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(AuraStrings.weeklyHits), findsOneWidget);
      expect(find.text(AuraStrings.topOfWeek), findsOneWidget);
      expect(find.text('Online 1'), findsWidgets);
      await scrollTo(tester, find.text(AuraStrings.popularNow));
      await scrollTo(tester, find.text(AuraStrings.homeLibraryHintTitle));
      // No sample (demo) content.
      expect(find.text(AuraStrings.demoBadge), findsNothing);
      expect(find.text(AuraStrings.homeEmptyTitle), findsNothing);
    });

    testWidgets('the hero plays the whole list; a top track plays from it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(
        iconButton(AuraStrings.playPlaylist(AuraStrings.weeklyHits)),
      );
      await tester.pumpAndSettle();
      expect(player.lastQueue!.map((t) => t.title), ['Online 1', 'Online 3']);
      expect(player.lastStartIndex, 0);

      // The chart's third row: link-only tracks are left out of the queue.
      final chartRow = find.text('3').first;
      await tester.tap(chartRow);
      await tester.pumpAndSettle();
      expect(player.lastStartIndex, 1);
      expect(links.opened, isEmpty);
    });

    testWidgets('a card plays the list, skipping link-only tracks', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(await scrollTo(tester, card('Online 3')));
      await tester.pumpAndSettle();

      expect(player.lastQueue!.map((t) => t.title), ['Online 1', 'Online 3']);
      expect(player.lastStartIndex, 1);
      expect(player.playCalls, 1);
      expect(links.opened, isEmpty);
    });

    testWidgets('a link-only track opens at its provider instead', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(await scrollTo(tester, card('Online 2')));
      await tester.pumpAndSettle();

      expect(links.opened, [Uri.parse('https://catalog.test/track/2')]);
      expect(player.playCalls, 0);
    });

    testWidgets('an artist of the week opens Search for that artist', (
      tester,
    ) async {
      await pump(tester);
      // The fake catalog has no artist pages: the artist is searched for.
      final artist = find.bySemanticsLabel(AuraStrings.openArtist('Artist 3'));
      await tester.tap(await scrollTo(tester, artist));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        find.widgetWithText(CupertinoSearchTextField, 'Artist 3'),
        findsOneWidget,
      );
      expect(catalog.searches.map((s) => s.$1), ['Artist 3']);
    });

    testWidgets('a catalog failure shows a retry, never fake tracks', (
      tester,
    ) async {
      catalog.popular = () async => const Err(NetworkFailure());
      await pump(tester);
      expect(find.text(AuraStrings.failureNetworkTitle), findsOneWidget);
      expect(find.text('Online 1'), findsNothing);

      catalog.popular = () async => Ok(ProviderPage(items: _popular));
      await tester.tap(find.text(AuraStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Online 1'), findsWidgets);
      expect(catalog.popularCalls, 2);
    });

    Track localTrack() => Track(
      id: const TrackId('local'),
      title: 'Своя песня',
      albumTitle: 'Свой альбом',
      artistName: 'Я',
      addedAt: DateTime(2026),
      sources: const [LocalFileSource('library:audio/local.mp3')],
    );

    testWidgets('with music in the library, the hero still comes first', (
      tester,
    ) async {
      await pump(tester);
      await library.addTracks([localTrack()]);
      await tester.pumpAndSettle();

      // Both sit in one column, so both are laid out: compare positions.
      expect(
        tester.getTopLeft(find.text(AuraStrings.weeklyHits)).dy,
        lessThan(
          tester.getTopLeft(find.text(AuraStrings.homeRecentlyAdded)).dy,
        ),
      );
    });

    testWidgets('the library shows even when the catalog fails', (
      tester,
    ) async {
      catalog.popular = () async => const Err(NetworkFailure());
      await pump(tester);
      await library.addTracks([localTrack()]);
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.failureNetworkTitle), findsOneWidget);
      await scrollTo(tester, find.text(AuraStrings.homeRecentlyAdded));
    });

    testWidgets('the hint leads to the Library', (tester) async {
      await pump(tester);
      final button = await scrollTo(
        tester,
        find.descendant(
          of: find.byType(AuraButton),
          matching: find.text(AuraStrings.tabLibrary),
        ),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.libraryEmptyTitle), findsOneWidget);
    });
  });

  group('Search', () {
    Future<void> type(WidgetTester tester, String query) async {
      await tester.tap(tab(AuraStrings.tabSearch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), query);
      await tester.pump(SearchQueryController.debounce);
      await tester.pumpAndSettle();
    }

    testWidgets('before typing: genres; a genre searches at once', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(tab(AuraStrings.tabSearch));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.genres), findsOneWidget);
      expect(find.text(AuraStrings.recentSearches), findsNothing);

      await tester.tap(find.text('Джаз'));
      await tester.pumpAndSettle();
      expect(catalog.searches.map((s) => s.$1), ['jazz']);
      expect(find.text('jazz 0'), findsOneWidget);
      // The field shows what was searched.
      expect(find.widgetWithText(CupertinoSearchTextField, 'jazz'), findsOne);
    });

    testWidgets('a query the user acted on is offered again', (tester) async {
      await pump(tester);
      await type(tester, 'ночь');
      await tester.tap(find.text('ночь 0'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(CupertinoSearchTextField), '');
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.recentSearches), findsOneWidget);
      await tester.tap(find.widgetWithText(AuraChip, 'ночь'));
      await tester.pumpAndSettle();
      // Asked again within minutes: answered from the session cache.
      expect(catalog.searches.map((s) => s.$1), ['ночь']);
      expect(find.text('ночь 0'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.clear));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.recentSearches), findsNothing);
    });

    testWidgets('online results appear in one "Онлайн" section', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'ночь');
      expect(find.text(AuraStrings.online), findsOneWidget);
      // No provider names in the interface.
      expect(find.text('Каталог'), findsNothing);
      expect(find.text('ночь 0'), findsOneWidget);
      expect(find.text('ночь 1'), findsOneWidget);

      await tester.tap(find.text(AuraStrings.showMore));
      await tester.pumpAndSettle();
      expect(find.text('ночь 2'), findsOneWidget);
      expect(find.text(AuraStrings.showMore), findsNothing);
    });

    testWidgets('two catalogs share one list, mixed, without names', (
      tester,
    ) async {
      final other = _CreditedCatalog(
        search: (query, page) async =>
            Ok(ProviderPage(items: [onlineTrack('c', provider: 'credited')])),
      );
      await pump(tester, providers: [catalog, other]);
      await type(tester, 'ночь');
      expect(find.text(AuraStrings.online), findsOneWidget);
      expect(find.text('Кредит'), findsNothing);
      final titles = [
        for (final tile in tester.widgetList<AuraListTile>(
          find.byType(AuraListTile),
        ))
          tile.title,
      ];
      expect(titles, ['ночь 0', 'Online c', 'ночь 1']);
    });

    testWidgets('one catalog failing leaves the other results', (tester) async {
      final broken = _CreditedCatalog(
        search: (_, _) async => const Err(NetworkFailure()),
      );
      await pump(tester, providers: [catalog, broken]);
      await type(tester, 'ночь');
      expect(find.text('ночь 0'), findsOneWidget);
      expect(find.text(AuraStrings.failureNetworkTitle), findsNothing);
      expect(find.text(AuraStrings.showMore), findsOneWidget);
    });

    testWidgets('a provider error is shown in its section with retry', (
      tester,
    ) async {
      var fail = true;
      catalog.search = (query, page) async => fail
          ? const Err(RateLimitedFailure())
          : Ok(ProviderPage(items: [onlineTrack('ok')]));
      await pump(tester);
      await type(tester, 'x');
      expect(find.text(AuraStrings.failureRateLimitedTitle), findsOneWidget);

      fail = false;
      await tester.tap(find.text(AuraStrings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Online ok'), findsOneWidget);
    });

    testWidgets('nothing anywhere shows the no-results state', (tester) async {
      catalog.search = (_, _) async => Ok(ProviderPage(items: const []));
      await pump(tester);
      await type(tester, 'zzz');
      expect(
        find.text(AuraStrings.searchNoResultsTitle('zzz')),
        findsOneWidget,
      );
    });

    testWidgets('the track menu opens the original page', (tester) async {
      await pump(tester);
      await type(tester, 'ночь');
      await tester.tap(iconButton('${AuraStrings.more}: ночь 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.openOriginal));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://catalog.test/track/s0')]);
    });

    testWidgets('a link that cannot be opened is explained', (tester) async {
      links.succeed = false;
      await pump(tester);
      await type(tester, 'ночь');
      await tester.tap(iconButton('${AuraStrings.more}: ночь 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.openOriginal));
      await tester.pumpAndSettle();
      expect(find.text(AuraStrings.linkOpenFailed), findsOneWidget);
    });
  });

  testWidgets('Now Playing names the source and links to it', (tester) async {
    player = FakePlaybackController(
      PlaybackSnapshot(
        queue: [onlineTrack('1')],
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

    expect(find.text(AuraStrings.openOriginal), findsOneWidget);
    await tester.tap(find.text(AuraStrings.openOriginal));
    await tester.pumpAndSettle();
    expect(links.opened, [Uri.parse('https://catalog.test/track/1')]);
    // An online track can be a favorite: saved as a reference only.
    await tester.tap(iconButton(AuraStrings.favoriteTrack));
    await tester.pumpAndSettle();
    expect(library.current.isFavorite(onlineTrack('1').id), isTrue);
    expect(library.current.tracks, isEmpty);
  });

  testWidgets('Now Playing credits a catalog whose terms require it', (
    tester,
  ) async {
    player = FakePlaybackController(
      PlaybackSnapshot(
        queue: [onlineTrack('1', provider: 'credited')],
        currentIndex: 0,
        status: PlaybackStatus.playing,
      ),
    );
    await pump(tester, providers: [catalog, _CreditedCatalog()]);
    unawaited(
      GoRouter.of(tester.element(find.byType(AuraTabBar)))
          .push(AppRoutes.nowPlaying),
    );
    await tester.pumpAndSettle();

    final credit = AuraStrings.sourceCredit('Кредит');
    expect(find.text(credit), findsOneWidget);
    expect(find.text(AuraStrings.openOriginal), findsNothing);
    await tester.tap(find.text(credit));
    await tester.pumpAndSettle();
    expect(links.opened, [Uri.parse('https://catalog.test/track/1')]);
  });

  for (final device in [iPhoneSE, iPhone15Landscape]) {
    testWidgets('$device, largest text: Home and Search lay out', (
      tester,
    ) async {
      await pump(tester, device: device, textScale: 3);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(tab(AuraStrings.tabSearch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'ночь');
      await tester.pump(SearchQueryController.debounce);
      await tester.pumpAndSettle();
      expect(find.text('ночь 0'), findsOneWidget);
    });
  }
}
