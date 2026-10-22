import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/domain/library/library_search.dart';
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
    return _Results(
      key: const ValueKey('results'),
      results: localEmpty ? null : results,
      online: online,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
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
  const _Results({super.key, required this.results, required this.online});

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
        for (final section in online) ...[
          SliverToBoxAdapter(child: header(section.providerName)),
          SliverList.list(
            children: [
              for (final track in section.tracks)
                OnlineTrackTile(track: track, list: section.tracks),
            ],
          ),
          SliverToBoxAdapter(child: _OnlineSectionFooter(section: section)),
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

/// Below a provider's results: progress, its own error with retry, "show
/// more", or a note that it found nothing.
class _OnlineSectionFooter extends ConsumerWidget {
  const _OnlineSectionFooter({required this.section});

  final OnlineSearchSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onlineSearchProvider.notifier);
    final failure = section.failure;
    final Widget? child = switch (section) {
      OnlineSearchSection(isLoading: true) => const SizedBox(
        height: AuraSizes.listTileMinHeight,
        child: AuraLoadingState(label: AuraStrings.loading),
      ),
      _ when failure != null => InlineErrorBox(
        error: failure,
        onRetry: () => unawaited(controller.retry(section.providerId)),
      ),
      OnlineSearchSection(hasMore: true) => Align(
        alignment: Alignment.centerLeft,
        child: AuraButton(
          label: AuraStrings.showMore,
          variant: AuraButtonVariant.secondary,
          onPressed: () => unawaited(controller.loadMore(section.providerId)),
        ),
      ),
      OnlineSearchSection(tracks: []) => Text(
        AuraStrings.nothingFoundIn(section.providerName),
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
