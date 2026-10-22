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
      expect(first!.providerName, 'Каталог');
      expect(again, same(first));
      expect(catalog.popularCalls, 1);
    });
  });
}
