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
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fake_providers.dart';
import '../../helpers/fakes.dart';

Finder tab(String label) =>
    find.descendant(of: find.byType(AuraTabBar), matching: find.text(label));

Finder iconButton(String semanticLabel) => find.byWidgetPredicate(
  (w) => w is AuraIconButton && w.semanticLabel == semanticLabel,
);

final _popular = [
  onlineTrack('1'),
  onlineTrack('2', availability: StreamAvailability.externalOnly),
  onlineTrack('3'),
];

void main() {
  late FakeCatalogProvider catalog;
  late FakeLinkOpener links;
  late FakePlaybackController player;

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
  }) async {
    final library = InMemoryLibraryRepository();
    await pumpAuraApp(
      tester,
      library: library,
      device: device,
      textScale: textScale,
      homeFeedSource: LibraryHomeFeedSource(repository: library),
      overrides: [
        providerRegistryProvider.overrideWithValue(ProviderRegistry([catalog])),
        externalLinkOpenerProvider.overrideWithValue(links),
        playbackControllerProvider.overrideWithValue(player),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('Home', () {
    testWidgets('an empty library shows the real catalog and an import hint', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text(AuraStrings.popularIn('Каталог')), findsOneWidget);
      expect(find.text('Online 1'), findsOneWidget);
      expect(find.text(AuraStrings.homeLibraryHintTitle), findsOneWidget);
      // No sample (demo) content.
      expect(find.text(AuraStrings.demoBadge), findsNothing);
      expect(find.text(AuraStrings.homeEmptyTitle), findsNothing);
    });

    testWidgets('a card plays the list, skipping link-only tracks', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Online 3'));
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
      expect(find.text(AuraStrings.onlyIn('Каталог')), findsOneWidget);
      await tester.tap(find.text('Online 2'));
      await tester.pumpAndSettle();

      expect(links.opened, [Uri.parse('https://catalog.test/track/2')]);
      expect(player.playCalls, 0);
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
      expect(find.text('Online 1'), findsOneWidget);
      expect(catalog.popularCalls, 2);
    });

    testWidgets('the hint leads to the Library', (tester) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.text(AuraStrings.tabLibrary).last,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AuraButton),
          matching: find.text(AuraStrings.tabLibrary),
        ),
      );
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

    testWidgets('online results appear under the provider name', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'ночь');
      expect(find.text('Каталог'), findsOneWidget);
      expect(find.text('ночь 0'), findsOneWidget);
      expect(find.text('ночь 1'), findsOneWidget);

      await tester.tap(find.text(AuraStrings.showMore));
      await tester.pumpAndSettle();
      expect(find.text('ночь 2'), findsOneWidget);
      expect(find.text(AuraStrings.showMore), findsNothing);
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
      await tester.tap(find.text(AuraStrings.openIn('Каталог')));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.parse('https://catalog.test/track/s0')]);
    });

    testWidgets('a link that cannot be opened is explained', (tester) async {
      links.succeed = false;
      await pump(tester);
      await type(tester, 'ночь');
      await tester.tap(iconButton('${AuraStrings.more}: ночь 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AuraStrings.openIn('Каталог')));
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

    expect(find.text(AuraStrings.sourceIs('Каталог')), findsOneWidget);
    await tester.tap(find.text(AuraStrings.sourceIs('Каталог')));
    await tester.pumpAndSettle();
    expect(links.opened, [Uri.parse('https://catalog.test/track/1')]);
    // Not a library track: no favorite heart.
    expect(iconButton(AuraStrings.favoriteTrack), findsNothing);
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
