import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Tracks from one provider, e.g. its popular list.
final class ProviderTracks {
  ProviderTracks({required this.providerName, required List<Track> tracks})
    : tracks = List.unmodifiable(tracks);

  final String providerName;
  final List<Track> tracks;
}

/// The first provider's popular tracks for Home, or null when no provider
/// offers a popular list. Loaded once per session (the Audius terms allow
/// only session caching); a failure is an error the screen can retry,
/// never retried automatically.
final popularTracksProvider = FutureProvider<ProviderTracks?>((ref) async {
  final registry = ref.watch(providerRegistryProvider);
  final provider = registry.all.whereType<PopularTracksProvider>().firstOrNull;
  if (provider == null) return null;

  final cancellation = Cancellation();
  ref.onDispose(cancellation.cancel);
  final result = await provider.popularTracks(
    page: const PageRequest(limit: 20),
    cancellation: cancellation,
  );
  return switch (result) {
    Ok(:final value) => ProviderTracks(
      providerName: provider.displayName,
      tracks: value.items,
    ),
    Err(:final failure) => throw failure,
  };
}, retry: (_, _) => null);

/// One provider's part of the online search results.
final class OnlineSearchSection {
  OnlineSearchSection({
    required this.providerId,
    required this.providerName,
    List<Track> tracks = const [],
    this.isLoading = false,
    this.failure,
    this.nextOffset,
  }) : tracks = List.unmodifiable(tracks);

  final ProviderId providerId;
  final String providerName;
  final List<Track> tracks;

  /// First page or the next page is on its way.
  final bool isLoading;

  /// The last request failed; earlier [tracks] stay visible.
  final AppFailure? failure;
  final int? nextOffset;

  bool get hasMore => nextOffset != null && !isLoading;

  OnlineSearchSection copyWith({
    List<Track>? tracks,
    bool? isLoading,
    AppFailure? Function()? failure,
    int? Function()? nextOffset,
  }) => OnlineSearchSection(
    providerId: providerId,
    providerName: providerName,
    tracks: tracks ?? this.tracks,
    isLoading: isLoading ?? this.isLoading,
    failure: failure == null ? this.failure : failure(),
    nextOffset: nextOffset == null ? this.nextOffset : nextOffset(),
  );
}

/// Searches every provider that can, independently: one failing or slow
/// provider never hides another's results. A new query cancels the
/// requests of the previous one (the debounced query rebuilds this).
final onlineSearchProvider =
    NotifierProvider<OnlineSearchController, List<OnlineSearchSection>>(
      OnlineSearchController.new,
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
    // No state access before the first await: build() calls this before
    // its state exists.
    final result = await provider.searchTracks(
      _query,
      page: PageRequest(offset: offset, limit: pageSize),
      cancellation: cancellation,
    );
    // A newer query took over: its own requests own the state.
    if (cancellation.isCancelled) return;

    switch (result) {
      case Ok(:final value):
        _update(id, (s) {
          final known = {for (final t in s.tracks) t.id};
          return s.copyWith(
            // Pages can overlap when the catalog changes between requests.
            tracks: [
              ...s.tracks,
              for (final t in value.items)
                if (known.add(t.id)) t,
            ],
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
