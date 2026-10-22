import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/domain/library/library_search.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/track_list_sliver.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';

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
    if (query.isEmpty) {
      return AuraEmptyState(
        key: const ValueKey('hint'),
        icon: CupertinoIcons.search,
        title: AuraStrings.searchHintTitle,
        message: hasMusic
            ? AuraStrings.searchHintMessageReady
            : AuraStrings.searchHintMessage,
      );
    }
    final results = ref.watch(librarySearchProvider);
    if (results == null || results.isEmpty) {
      return AuraEmptyState(
        key: const ValueKey('no-results'),
        icon: CupertinoIcons.search,
        title: AuraStrings.searchNoResultsTitle(query),
        message: hasMusic
            ? AuraStrings.searchNoResultsInLibrary
            : AuraStrings.searchNoResultsMessage,
      );
    }
    return _Results(key: const ValueKey('results'), results: results);
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
  const _Results({super.key, required this.results});

  final LibrarySearchResult results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget header(String title) => Padding(
      padding: const EdgeInsets.only(
        top: AuraSpacing.xl,
        bottom: AuraSpacing.xs,
      ),
      child: AuraSectionHeader(title: title),
    );

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
        SliverToBoxAdapter(
          child: SizedBox(
            height: AuraSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}
