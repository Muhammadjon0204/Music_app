import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/providers/external_links.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Online providers of this build; empty in tests unless overridden.
final providerRegistryProvider = Provider<ProviderRegistry>(
  (ref) => ProviderRegistry.empty,
);

/// Null where links cannot be opened (tests).
final externalLinkOpenerProvider = Provider<ExternalLinkOpener?>((ref) => null);

/// Popular tracks of every provider that has a list, interleaved into one
/// list for Home, or null when no provider offers one. Loaded once per
/// session (the providers' terms allow only session caching). A provider
/// that fails is left out; only when all fail is it an error the screen can
/// retry, never retried automatically.
final popularTracksProvider = FutureProvider<List<Track>?>((ref) async {
  final registry = ref.watch(providerRegistryProvider);
  final providers = registry.all.whereType<PopularTracksProvider>().toList();
  if (providers.isEmpty) return null;

  final cancellation = Cancellation();
  ref.onDispose(cancellation.cancel);
  final results = await Future.wait([
    for (final provider in providers)
      provider.popularTracks(
        page: const PageRequest(limit: 20),
        cancellation: cancellation,
      ),
  ]);
  final lists = [
    for (final result in results)
      if (result case Ok(:final value)) value.items,
  ];
  if (lists.isEmpty) throw (results.first as Err<ProviderPage<Track>>).failure;
  final tracks = interleave(lists);
  ref.read(onlineTrackCacheProvider.notifier).remember(tracks);
  return tracks;
}, retry: (_, _) => null);

/// One item of each list in turn: `[a1, b1, a2, b2, a3]`. Keeps every
/// catalog visible near the top instead of one after another.
List<T> interleave<T>(List<List<T>> lists) => [
  for (var i = 0; lists.any((l) => i < l.length); i++)
    for (final list in lists)
      if (i < list.length) list[i],
];

/// One provider's part of the online search results.
final class OnlineSearchSection {
  OnlineSearchSection({
    required this.providerId,
    required this.providerName,
    List<Track> tracks = const [],
    this.isLoading = false,
    List<int> pageEnds = const [],
    this.failure,
    this.nextOffset,
  }) : tracks = List.unmodifiable(tracks),
       pageEnds = List.unmodifiable(pageEnds);

  final ProviderId providerId;
  final String providerName;
  final List<Track> tracks;

  /// Where each loaded page ends in [tracks], for [mergedTracks].
  final List<int> pageEnds;

  /// The tracks of each loaded page.
  List<List<Track>> get pages => [
    for (final (i, end) in pageEnds.indexed)
      tracks.sublist(i == 0 ? 0 : pageEnds[i - 1], end),
  ];

  /// First page or the next page is on its way.
  final bool isLoading;

  /// The last request failed; earlier [tracks] stay visible.
  final AppFailure? failure;
  final int? nextOffset;

  bool get hasMore => nextOffset != null && !isLoading;

  OnlineSearchSection copyWith({
    List<Track>? tracks,
    List<int>? pageEnds,
    bool? isLoading,
    AppFailure? Function()? failure,
    int? Function()? nextOffset,
  }) => OnlineSearchSection(
    providerId: providerId,
    providerName: providerName,
    tracks: tracks ?? this.tracks,
    pageEnds: pageEnds ?? this.pageEnds,
    isLoading: isLoading ?? this.isLoading,
    failure: failure == null ? this.failure : failure(),
    nextOffset: nextOffset == null ? this.nextOffset : nextOffset(),
  );
}

/// The results of all [sections] as one list: page by page, the providers'
/// tracks interleaved. Loading more only adds at the end, because every
/// provider's next page comes after all first pages.
List<Track> mergedTracks(List<OnlineSearchSection> sections) {
  final pages = [for (final s in sections) s.pages];
  final depth = pages.fold(0, (max, p) => p.length > max ? p.length : max);
  return [
    for (var page = 0; page < depth; page++)
      ...interleave([
        for (final p in pages)
          if (page < p.length) p[page],
      ]),
  ];
}

/// Searches every provider that can, independently: one failing or slow
/// provider never hides another's results. A new query cancels the
/// requests of the previous one (the debounced query rebuilds this).
final onlineSearchProvider =
    NotifierProvider<OnlineSearchController, List<OnlineSearchSection>>(
      OnlineSearchController.new,
    );

/// Search answers of this session, so a query asked again (or the way
/// back to it) shows its results at once. Memory only, briefly: catalogs
/// change, and their terms allow no lasting copy.
final class SearchPageCache {
  SearchPageCache({required this._now});

  static const ttl = Duration(minutes: 10);
  static const maxPages = 100;

  final DateTime Function() _now;
  final _pages = <(ProviderId, String, int), (ProviderPage<Track>, DateTime)>{};

  static (ProviderId, String, int) _key(
    ProviderId provider,
    String query,
    int offset,
  ) => (provider, query.trim().toLowerCase(), offset);

  ProviderPage<Track>? get(ProviderId provider, String query, int offset) {
    final key = _key(provider, query, offset);
    final entry = _pages[key];
    if (entry == null) return null;
    if (_now().difference(entry.$2) >= ttl) {
      _pages.remove(key);
      return null;
    }
    return entry.$1;
  }

  void put(
    ProviderId provider,
    String query,
    int offset,
    ProviderPage<Track> page,
  ) {
    _pages[_key(provider, query, offset)] = (page, _now());
    while (_pages.length > maxPages) {
      _pages.remove(_pages.keys.first);
    }
  }
}

final searchPageCacheProvider = Provider<SearchPageCache>(
  (ref) => SearchPageCache(now: ref.watch(clockProvider)),
);

class OnlineSearchController extends Notifier<List<OnlineSearchSection>> {
  static const pageSize = 20;

  late Cancellation _cancellation;
  late String _query;
  late Map<ProviderId, SearchableProvider> _providers;

  @override
  List<OnlineSearchSection> build() {
    _query = ref.watch(searchQueryProvider);
    _providers = {
      for (final p
          in ref
              .watch(providerRegistryProvider)
              .all
              .whereType<SearchableProvider>())
        p.id: p,
    };
    final cancellation = _cancellation = Cancellation();
    ref.onDispose(cancellation.cancel);
    if (_query.isEmpty || _providers.isEmpty) return const [];

    for (final id in _providers.keys) {
      unawaited(_load(id, offset: 0, cancellation: cancellation));
    }
    return [
      for (final p in _providers.values)
        OnlineSearchSection(
          providerId: p.id,
          providerName: p.displayName,
          isLoading: true,
        ),
    ];
  }

  /// Next page for [providerId]; ignored while a request is running.
  Future<void> loadMore(ProviderId providerId) async {
    final section = _section(providerId);
    final offset = section?.nextOffset;
    if (section == null || section.isLoading || offset == null) return;
    _markLoading(providerId);
    await _load(providerId, offset: offset, cancellation: _cancellation);
  }

  /// Next page of every provider at once, for the merged list; a provider
  /// whose last request failed is asked again instead.
  Future<void> loadMoreAll() => Future.wait([
    for (final section in state)
      if (section.failure != null)
        retry(section.providerId)
      else if (section.hasMore)
        loadMore(section.providerId),
  ]);

  /// Repeats the request that failed (first page or next page).
  Future<void> retry(ProviderId providerId) async {
    final section = _section(providerId);
    if (section == null || section.isLoading || section.failure == null) {
      return;
    }
    _markLoading(providerId);
    await _load(
      providerId,
      offset: section.tracks.isEmpty ? 0 : section.nextOffset ?? 0,
      cancellation: _cancellation,
    );
  }

  OnlineSearchSection? _section(ProviderId id) =>
      state.where((s) => s.providerId == id).firstOrNull;

  Future<void> _load(
    ProviderId id, {
    required int offset,
    required Cancellation cancellation,
  }) async {
    final provider = _providers[id];
    if (provider == null) return;
    final cache = ref.read(searchPageCacheProvider);
    final cached = cache.get(id, _query, offset);
    final Result<ProviderPage<Track>> result;
    if (cached != null) {
      // No state access before the first await: build() calls this before
      // its state exists.
      await Future<void>.value();
      result = Ok(cached);
    } else {
      result = await provider.searchTracks(
        _query,
        page: PageRequest(offset: offset, limit: pageSize),
        cancellation: cancellation,
      );
      if (result case Ok(:final value)) cache.put(id, _query, offset, value);
    }
    // A newer query took over: its own requests own the state.
    if (cancellation.isCancelled) return;

    switch (result) {
      case Ok(:final value):
        ref.read(onlineTrackCacheProvider.notifier).remember(value.items);
        _update(id, (s) {
          final known = {for (final t in s.tracks) t.id};
          // Pages can overlap when the catalog changes between requests.
          final tracks = [
            ...s.tracks,
            for (final t in value.items)
              if (known.add(t.id)) t,
          ];
          return s.copyWith(
            tracks: tracks,
            pageEnds: [...s.pageEnds, tracks.length],
            isLoading: false,
            nextOffset: () => value.nextOffset,
          );
        });
      case Err(:final failure):
        if (failure is CancelledFailure) return;
        _update(
          id,
          (s) => s.copyWith(isLoading: false, failure: () => failure),
        );
    }
  }

  void _markLoading(ProviderId id) =>
      _update(id, (s) => s.copyWith(isLoading: true, failure: () => null));

  void _update(
    ProviderId id,
    OnlineSearchSection Function(OnlineSearchSection section) change,
  ) {
    state = [
      for (final s in state)
        if (s.providerId == id) change(s) else s,
    ];
  }
}
