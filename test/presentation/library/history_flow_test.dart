import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/in_memory_listening_store.dart';
import 'package:music_app/data/library/library_home_feed_source.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fake_providers.dart';
import '../../helpers/fakes.dart';

class _Catalog implements BatchTrackDetailsProvider {
  final known = {'1': onlineTrack('1')};
  AppFailure? failWith;

  @override
  ProviderId get id => const ProviderId('catalog');

  @override
  String get displayName => 'Каталог';

  @override
  Future<Result<List<Track>>> tracksByIds(
    List<ExternalTrackId> ids, {
    Cancellation? cancellation,
  }) async {
    final failure = failWith;
    if (failure != null) return Err(failure);
    return Ok([for (final i in ids) ?known[i.value]]);
  }
}

final _local = Track(
  id: const TrackId('local-1'),
  title: 'Мой трек',
  sources: const [LocalFileSource('/m/1.mp3')],
);

void main() {
  late InMemoryLibraryRepository library;
  late InMemoryListeningStore store;
  late _Catalog catalog;
  late FakePlaybackController player;

  setUp(() async {
    library = InMemoryLibraryRepository();
    await library.addTracks([_local]);
    store = InMemoryListeningStore();
    catalog = _Catalog();
    player = FakePlaybackController(PlaybackSnapshot.initial);
  });

  Future<void> listened(String id, int minute) => store.addToHistory(
    HistoryEntry(
      trackId: TrackId(id),
      playedAt: DateTime(2026, 1, 1, 12, minute),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await pumpAuraApp(
      tester,
      library: library,
      homeFeedSource: LibraryHomeFeedSource(repository: library),
      overrides: [
        listeningStoreProvider.overrideWithValue(store),
        providerRegistryProvider.overrideWithValue(ProviderRegistry([catalog])),
        playbackControllerProvider.overrideWithValue(player),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(AuraTabBar))).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('history lists each recent track once, local and online', (
    tester,
  ) async {
    await listened('local-1', 1);
    await listened('catalog:1', 2);
    await listened('local-1', 3);
    await listened('catalog:gone', 4);
    await pump(tester);
    await go(tester, AppRoutes.libraryHistory);

    expect(find.text('Мой трек'), findsOneWidget);
    expect(find.text('Online 1'), findsOneWidget);
    expect(find.text(AuraStrings.savedUnavailable(1)), findsOneWidget);

    // Playing from history queues the history.
    await tester.tap(find.text('Online 1'));
    await tester.pumpAndSettle();
    expect(player.lastQueue!.map((t) => t.title), ['Мой трек', 'Online 1']);
  });

  testWidgets('history can be cleared after confirming', (tester) async {
    await listened('local-1', 1);
    await pump(tester);
    await go(tester, AppRoutes.libraryHistory);

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is AuraIconButton && w.semanticLabel == AuraStrings.clearHistory,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text(AuraStrings.clear),
      ),
    );
    await tester.pumpAndSettle();
    expect(await store.watchHistory().first, isEmpty);
    expect(find.text(AuraStrings.historyEmptyTitle), findsOneWidget);
  });

  testWidgets('empty history explains itself', (tester) async {
    await pump(tester);
    await go(tester, AppRoutes.libraryHistory);
    expect(find.text(AuraStrings.historyEmptyTitle), findsOneWidget);
  });

  testWidgets('online favorites appear in Favorites, looked up again', (
    tester,
  ) async {
    await library.setFavorite(const TrackId('catalog:1'), favorite: true);
    await pump(tester);
    await go(tester, AppRoutes.libraryFavorites);

    expect(find.text(AuraStrings.online), findsOneWidget);
    expect(find.text('Online 1'), findsOneWidget);
    // Only the reference is stored in the library.
    expect(library.current.tracks.map((t) => t.title), ['Мой трек']);
  });

  testWidgets('offline, online favorites show a retry instead', (tester) async {
    catalog.failWith = const NetworkFailure();
    await library.setFavorite(const TrackId('catalog:1'), favorite: true);
    await pump(tester);
    await go(tester, AppRoutes.libraryFavorites);
    expect(find.text(AuraStrings.failureNetworkTitle), findsOneWidget);

    catalog.failWith = null;
    await tester.tap(find.text(AuraStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text('Online 1'), findsOneWidget);
  });

  testWidgets('Home shows recently played and links to the history', (
    tester,
  ) async {
    await listened('catalog:1', 1);
    await pump(tester);
    expect(find.text(AuraStrings.recentlyPlayed), findsOneWidget);
    expect(find.text('Online 1'), findsOneWidget);

    await tester.tap(find.text(AuraStrings.history));
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(tester.element(find.byType(AuraTabBar)))
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.libraryHistory,
    );
  });
}
