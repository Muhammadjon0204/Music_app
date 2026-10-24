import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';

/// Sets the query directly, skipping the debounce.
class _Query extends SearchQueryController {
  void set(String query) => state = query;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;

  ProviderContainer create(List<MusicProvider> providers) {
    container = ProviderContainer.test(
      overrides: [
        providerRegistryProvider.overrideWithValue(ProviderRegistry(providers)),
        searchQueryProvider.overrideWith(_Query.new),
      ],
    );
    // Riverpod pauses providers nobody listens to.
    container.listen(onlineSearchProvider, (_, _) {});
    return container;
  }

  void search(String query) =>
      (container.read(searchQueryProvider.notifier) as _Query).set(query);

  List<OnlineSearchSection> sections() => container.read(onlineSearchProvider);

  group('online search', () {
    test('no query, no requests', () async {
      final catalog = FakeCatalogProvider();
      create([catalog]);
      await _settle();
      expect(sections(), isEmpty);
      expect(catalog.searches, isEmpty);
    });

    test('one failing provider never hides another\'s results', () async {
      final good = FakeCatalogProvider(
        providerId: const ProviderId('good'),
        name: 'Хороший',
        search: (_, _) async =>
            Ok(ProviderPage(items: [onlineTrack('1', provider: 'good')])),
      );
      final bad = FakeCatalogProvider(
        providerId: const ProviderId('bad'),
        name: 'Плохой',
        search: (_, _) async => const Err(ServerFailure(statusCode: 503)),
      );
      create([good, bad]);
      search('ночь');
      expect(sections().every((s) => s.isLoading), isTrue);
      await _settle();

      final byName = {for (final s in sections()) s.providerName: s};
      expect(byName['Хороший']!.tracks, hasLength(1));
      expect(byName['Хороший']!.failure, isNull);
      expect(byName['Плохой']!.tracks, isEmpty);
      expect(byName['Плохой']!.failure, isA<ServerFailure>());
    });

    test('a new query cancels the old requests and wins', () async {
      final slow = Completer<Result<ProviderPage<Track>>>();
      final catalog = FakeCatalogProvider(
        search: (query, _) => query == 'old'
            ? slow.future
            : Future.value(Ok(ProviderPage(items: [onlineTrack('new')]))),
      );
      create([catalog]);
      search('old');
      await _settle();
      search('new');
      await _settle();
      expect(catalog.searchCancellations.first!.isCancelled, isTrue);

      slow.complete(Ok(ProviderPage(items: [onlineTrack('old')])));
      await _settle();
      expect(sections().single.tracks.map((t) => t.title), ['Online new']);
    });

    test('more results append, without duplicates', () async {
      final catalog = FakeCatalogProvider(
        search: (_, page) async => page.offset == 0
            ? Ok(
                ProviderPage(
                  items: [onlineTrack('1'), onlineTrack('2')],
                  nextOffset: 2,
                ),
              )
            : Ok(ProviderPage(items: [onlineTrack('2'), onlineTrack('3')])),
      );
      create([catalog]);
      search('x');
      await _settle();
      expect(sections().single.hasMore, isTrue);

      await container
          .read(onlineSearchProvider.notifier)
          .loadMore(catalog.providerId);
      final section = sections().single;
      expect(section.tracks.map((t) => t.title), [
        'Online 1',
        'Online 2',
        'Online 3',
      ]);
      expect(section.hasMore, isFalse);
      expect(catalog.searches.map((s) => s.$2), [0, 2]);
    });

    test('retry repeats only the failed request', () async {
      var fail = true;
      final catalog = FakeCatalogProvider(
        search: (_, _) async => fail
            ? const Err(TimeoutFailure())
            : Ok(ProviderPage(items: [onlineTrack('1')])),
      );
      create([catalog]);
      search('x');
      await _settle();
      expect(sections().single.failure, isA<TimeoutFailure>());

      fail = false;
      await container
          .read(onlineSearchProvider.notifier)
          .retry(catalog.providerId);
      expect(sections().single.failure, isNull);
      expect(sections().single.tracks, hasLength(1));
      expect(catalog.searches, hasLength(2));
    });

    test('results of all providers are merged page by page', () async {
      ProviderPage<Track> page(String provider, int offset) => ProviderPage(
        items: [
          for (var i = offset; i < offset + 2; i++)
            onlineTrack('$i', provider: provider),
        ],
        nextOffset: offset == 0 ? 2 : null,
      );
      final a = FakeCatalogProvider(
        providerId: const ProviderId('a'),
        search: (_, p) async => Ok(page('a', p.offset)),
      );
      final b = FakeCatalogProvider(
        providerId: const ProviderId('b'),
        search: (_, p) async => Ok(page('b', p.offset)),
      );
      create([a, b]);
      search('x');
      await _settle();
      String ids() =>
          mergedTracks(sections())
              .map((t) => t.id.value.replaceAll(':', ''))
              .join(' ');
      expect(ids(), 'a0 b0 a1 b1');

      await container.read(onlineSearchProvider.notifier).loadMoreAll();
      // The second pages come after all first pages: nothing shown moves.
      expect(ids(), 'a0 b0 a1 b1 a2 b2 a3 b3');
      expect(sections().every((s) => !s.hasMore), isTrue);
    });

    test('"show more" also asks a failed provider again', () async {
      var fail = true;
      final good = FakeCatalogProvider(
        providerId: const ProviderId('good'),
        search: (_, _) async =>
            Ok(ProviderPage(items: [onlineTrack('1', provider: 'good')])),
      );
      final flaky = FakeCatalogProvider(
        providerId: const ProviderId('flaky'),
        search: (_, _) async => fail
            ? const Err(TimeoutFailure())
            : Ok(ProviderPage(items: [onlineTrack('2', provider: 'flaky')])),
      );
      create([good, flaky]);
      search('x');
      await _settle();
      expect(mergedTracks(sections()), hasLength(1));

      fail = false;
      await container.read(onlineSearchProvider.notifier).loadMoreAll();
      expect(mergedTracks(sections()).map((t) => t.id.value), [
        'good:1',
        'flaky:2',
      ]);
      expect(good.searches, hasLength(1));
    });

    test('nothing is retried automatically', () async {
      final catalog = FakeCatalogProvider(
        search: (_, _) async => const Err(RateLimitedFailure()),
      );
      create([catalog]);
      search('x');
      await _settle();
      await _settle();
      expect(catalog.searches, hasLength(1));
    });
  });

  group('popular tracks', () {
    test('null when no provider offers a popular list', () async {
      final container = ProviderContainer.test();
      expect(await container.read(popularTracksProvider.future), isNull);
    });

    test(
      'a failure is an error, not an empty list, and is not retried',
      () async {
        final catalog = FakeCatalogProvider(
          popular: () async => const Err(NetworkFailure()),
        );
        final container = ProviderContainer.test(
          overrides: [
            providerRegistryProvider.overrideWithValue(
              ProviderRegistry([catalog]),
            ),
          ],
        );
        container.listen(popularTracksProvider, (_, _) {});
        await expectLater(
          container.read(popularTracksProvider.future),
          throwsA(isA<NetworkFailure>()),
        );
        await _settle();
        expect(catalog.popularCalls, 1);
      },
    );

    test('lists of all providers are mixed; one failing is left out', () async {
      ProviderRegistry registry(bool bFails) => ProviderRegistry([
        FakeCatalogProvider(
          providerId: const ProviderId('a'),
          popular: () async => Ok(
            ProviderPage(
              items: [
                onlineTrack('1', provider: 'a'),
                onlineTrack('2', provider: 'a'),
              ],
            ),
          ),
        ),
        FakeCatalogProvider(
          providerId: const ProviderId('b'),
          popular: () async => bFails
              ? const Err(NetworkFailure())
              : Ok(ProviderPage(items: [onlineTrack('3', provider: 'b')])),
        ),
      ]);
      Future<List<String>> load(bool bFails) async {
        final container = ProviderContainer.test(
          overrides: [
            providerRegistryProvider.overrideWithValue(registry(bFails)),
          ],
        );
        container.listen(popularTracksProvider, (_, _) {});
        final tracks = await container.read(popularTracksProvider.future);
        return [for (final t in tracks!) t.id.value];
      }

      expect(await load(false), ['a:1', 'b:3', 'a:2']);
      expect(await load(true), ['a:1', 'a:2']);
    });

    test('interleave takes one of each in turn', () {
      expect(
        interleave([
          [1, 2, 3],
          <int>[],
          [10],
        ]),
        [1, 10, 2, 3],
      );
      expect(interleave(<List<int>>[]), isEmpty);
    });

    test('loaded once per session', () async {
      final catalog = FakeCatalogProvider(
        popular: () async => Ok(ProviderPage(items: [onlineTrack('1')])),
      );
      final container = ProviderContainer.test(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry([catalog]),
          ),
        ],
      );
      container.listen(popularTracksProvider, (_, _) {});
      final first = await container.read(popularTracksProvider.future);
      final again = await container.read(popularTracksProvider.future);
      expect(first!.map((t) => t.title), ['Online 1']);
      expect(again, same(first));
      expect(catalog.popularCalls, 1);
    });
  });
}
