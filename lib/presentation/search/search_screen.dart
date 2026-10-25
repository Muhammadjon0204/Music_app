import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/domain/library/library_search.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/track_list_sliver.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';
import 'package:music_app/presentation/online/online_tracks.dart';
import 'package:music_app/presentation/online/popular_tracks_section.dart';
import 'package:music_app/presentation/search/genres.dart';

/// Searches the user's library: tracks, albums and artists.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.focusRequest});

  /// When it changes, the field takes focus (e.g. after tapping the search
  /// field on Home).
  final String? focusRequest;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // A search started elsewhere (an artist or genre on Home) shows here.
    _controller.text = ref.read(searchQueryProvider);
    if (widget.focusRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.focusRequest;
    if (request != null && request != oldWidget.focusRequest) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _body(String query) {
    final library = ref.watch(librarySnapshotProvider).value;
    final hasMusic = !(library?.isEmpty ?? true);
    final online = ref.watch(onlineSearchProvider);
    final searchesOnline = ref
        .watch(providerRegistryProvider)
        .all
        .any((p) => p is SearchableProvider);
    if (query.isEmpty && searchesOnline) {
      return _SearchStart(key: const ValueKey('start'), onSearch: _searchNow);
    }
    if (query.isEmpty) {
      return AuraEmptyState(
        key: const ValueKey('hint'),
        icon: CupertinoIcons.search,
        title: AuraStrings.searchHintTitle,
        message: searchesOnline
            ? AuraStrings.searchHintMessageOnline
            : hasMusic
            ? AuraStrings.searchHintMessageReady
            : AuraStrings.searchHintMessage,
      );
    }
    final results = ref.watch(librarySearchProvider);
    final localEmpty = results == null || results.isEmpty;
    final onlineShowsSomething = online.any(
      (s) => s.tracks.isNotEmpty || s.isLoading || s.failure != null,
    );
    if (localEmpty && !onlineShowsSomething) {
      return AuraEmptyState(
        key: const ValueKey('no-results'),
        icon: CupertinoIcons.search,
        title: AuraStrings.searchNoResultsTitle(query),
        message: hasMusic
            ? AuraStrings.searchNoResultsInLibrary
            : AuraStrings.searchNoResultsMessage,
      );
    }
    // Tapping or scrolling the results means the query was useful.
    return Listener(
      key: const ValueKey('results'),
      onPointerDown: (_) => _remember(),
      child: _Results(results: localEmpty ? null : results, online: online),
    );
  }

  /// Runs [query] at once (a genre or a recent search) and shows it in the
  /// field.
  void _searchNow(String query) {
    _controller.text = query;
    _focusNode.unfocus();
    ref.read(searchQueryProvider.notifier).searchNow(query);
    ref.read(settingsProvider.notifier).addRecentSearch(query);
  }

  /// A query the user acted on is worth offering again.
  void _remember() {
    final query = ref.read(searchQueryProvider);
    if (query.isNotEmpty) {
      ref.read(settingsProvider.notifier).addRecentSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    ref.listen<String>(searchQueryProvider, (_, next) {
      if (!_focusNode.hasFocus && _controller.text.trim() != next) {
        _controller.text = next;
      }
    });
    final text = context.auraText;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.screenHorizontal,
                  AuraSpacing.lg,
                  AuraSpacing.screenHorizontal,
                  AuraSpacing.md,
                ),
                child: Semantics(
                  header: true,
                  child: Text(AuraStrings.tabSearch, style: text.largeTitle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.screenHorizontal,
                ),
                child: AuraSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: AuraStrings.searchPlaceholder,
                  onChanged: ref
                      .read(searchQueryProvider.notifier)
                      .onInputChanged,
                  onSubmitted: (input) {
                    ref.read(searchQueryProvider.notifier).searchNow(input);
                    _remember();
                  },
                ),
              ),
              Expanded(
                // Tapping outside the field hides the keyboard.
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // A convenience for touch only; VoiceOver users dismiss the
                  // keyboard natively, and an unlabeled full-screen "button"
                  // would only confuse them.
                  excludeFromSemantics: true,
                  onTap: _focusNode.unfocus,
                  child: AuraStateSwitcher(child: _body(query)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.online});

  /// Library matches; null when there are none.
  final LibrarySearchResult? results;
  final List<OnlineSearchSection> online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget header(String title) => Padding(
      padding: const EdgeInsets.only(
        top: AuraSpacing.xl,
        bottom: AuraSpacing.xs,
      ),
      child: AuraSectionHeader(title: title),
    );
    final results = this.results ?? const LibrarySearchResult();
    // Every catalog in one list, without saying where each track is from.
    final onlineTracks = mergedTracks(online);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (results.artists.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(AuraStrings.artists)),
          SliverList.list(
            children: [
              for (final artist in results.artists)
                AuraListTile(
                  title: artist.name,
                  leading: AuraArtwork(
                    size: AuraSizes.artworkListTile,
                    shape: AuraArtworkShape.circle,
                    placeholderSeed: artist.name,
                  ),
                  onPressed: () =>
                      openDetail(context, DetailKind.artist, artist.id.value),
                ),
            ],
          ),
        ],
        if (results.albums.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(AuraStrings.albums)),
          SliverList.list(
            children: [
              for (final album in results.albums)
                AuraListTile(
                  title: album.title,
                  subtitle: album.artistName ?? AuraStrings.unknownArtist,
                  leading: AuraArtwork(
                    size: AuraSizes.artworkListTile,
                    image: artworkImage(ref, album.artworkUri),
                    placeholderSeed: album.title,
                  ),
                  onPressed: () =>
                      openDetail(context, DetailKind.album, album.id.value),
                ),
            ],
          ),
        ],
        if (results.tracks.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(AuraStrings.searchSectionTracks)),
          TrackListSliver(tracks: results.tracks),
        ],
        if (online.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(AuraStrings.online)),
          SliverList.list(
            children: [
              for (final track in onlineTracks)
                OnlineTrackTile(track: track, list: onlineTracks),
            ],
          ),
          SliverToBoxAdapter(
            child: _OnlineFooter(sections: online, tracks: onlineTracks),
          ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height: AuraSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// Below the online results: progress, an error with retry when nothing
/// came back, "show more" (which also asks again a catalog that failed),
/// or a note that nothing was found.
class _OnlineFooter extends ConsumerWidget {
  const _OnlineFooter({required this.sections, required this.tracks});

  final List<OnlineSearchSection> sections;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onlineSearchProvider.notifier);
    final failure = sections.map((s) => s.failure).nonNulls.firstOrNull;
    final Widget? child = switch (sections) {
      _ when sections.any((s) => s.isLoading) => const SizedBox(
        height: AuraSizes.listTileMinHeight,
        child: AuraLoadingState(label: AuraStrings.loading),
      ),
      _ when failure != null && tracks.isEmpty => InlineErrorBox(
        error: failure,
        onRetry: () => unawaited(controller.loadMoreAll()),
      ),
      _ when failure != null || sections.any((s) => s.hasMore) => Align(
        alignment: Alignment.centerLeft,
        child: AuraButton(
          label: AuraStrings.showMore,
          variant: AuraButtonVariant.secondary,
          onPressed: () => unawaited(controller.loadMoreAll()),
        ),
      ),
      _ when tracks.isEmpty => Text(
        AuraStrings.nothingFoundOnline,
        style: context.auraText.subhead,
      ),
      _ => null,
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
        vertical: AuraSpacing.sm,
      ),
      child: child,
    );
  }
}

/// Before typing: recent searches and genres, each a tap from results.
class _SearchStart extends ConsumerWidget {
  const _SearchStart({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(settingsProvider.select((s) => s.recentSearches));
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AuraSpacing.lg),
              child: AuraSectionHeader(
                title: AuraStrings.recentSearches,
                actionLabel: AuraStrings.clear,
                onAction: ref
                    .read(settingsProvider.notifier)
                    .clearRecentSearches,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpacing.screenHorizontal,
              AuraSpacing.xs,
              AuraSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: AuraSpacing.sm,
                runSpacing: AuraSpacing.sm,
                children: [
                  for (final query in recent)
                    AuraChip(label: query, onPressed: () => onSearch(query)),
                ],
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: AuraSpacing.xxl,
              bottom: AuraSpacing.md,
            ),
            child: AuraSectionHeader(title: AuraStrings.genres),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.screenHorizontal,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 520 ? 4 : 2;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AuraSpacing.md,
                  crossAxisSpacing: AuraSpacing.md,
                  // Taller tiles when the text is large.
                  mainAxisExtent:
                      MediaQuery.textScalerOf(context).scale(52) + 36,
                ),
                itemCount: searchGenres.length,
                itemBuilder: (context, index) => GenreTile(
                  genre: searchGenres[index],
                  index: index,
                  onPressed: () => onSearch(searchGenres[index].query),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AuraSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}
