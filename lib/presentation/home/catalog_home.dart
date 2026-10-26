import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_artist_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';
import 'package:music_app/presentation/online/online_tracks.dart';
import 'package:music_app/presentation/online/popular_tracks_section.dart';
import 'package:music_app/presentation/search/genres.dart';
import 'package:music_app/presentation/search/open_search.dart';

/// The catalog part of Home, built only from the real "popular this week"
/// lists: a swipeable hero, the weekly top 10, artists of the week, more
/// popular tracks and genres. Nothing is invented: with no catalog it is
/// hidden, and a failure offers a retry.
class CatalogHome extends ConsumerWidget {
  const CatalogHome({super.key, this.afterHero});

  /// Placed right below the hero (e.g. recently played).
  final Widget? afterHero;

  static const _maxTracks = 24;
  static const _heroPages = 4;
  static const _chartSize = 10;
  static const _maxArtists = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularTracksProvider);
    final value = popular.value;
    final error = popular.error;

    // What comes after the hero (the library, recently played) shows in
    // every state: it never waits for the catalog.
    if (value == null) {
      final Widget top;
      if (error != null && !popular.isLoading) {
        top = Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.screenHorizontal,
            AuraSpacing.sectionGap,
            AuraSpacing.screenHorizontal,
            0,
          ),
          child: InlineErrorBox(
            error: error,
            onRetry: () => ref.invalidate(popularTracksProvider),
          ),
        );
      } else if (popular.isLoading) {
        top = const _CatalogSkeleton();
      } else {
        return afterHero ?? const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [top, ?afterHero],
      );
    }
    if (value.isEmpty) return afterHero ?? const SizedBox.shrink();

    final tracks = value.take(_maxTracks).toList();
    final playable = tracks.where(canPlayInApp).toList();
    void play(Track track) =>
        unawaited(playOnline(context, ref, tracks, track));

    final artists = <String, Track>{};
    for (final track in tracks) {
      final name = track.artistName;
      if (name != null && name.trim().isNotEmpty) {
        artists.putIfAbsent(name, () => track);
      }
      if (artists.length == _maxArtists) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AuraSpacing.xxl),
        _HeroPager(
          trackCount: tracks.length,
          featured: playable.take(_heroPages).toList(),
          onPlayAll: playable.isEmpty ? null : () => play(playable.first),
          onPlay: play,
        ),
        ?afterHero,
        _Section(
          title: AuraStrings.topOfWeek,
          child: _TopChart(
            tracks: tracks.take(_chartSize).toList(),
            onPlay: play,
          ),
        ),
        if (artists.length > 1)
          _Section(
            title: AuraStrings.artistsOfWeek,
            child: _Shelf(
              children: [
                for (final MapEntry(key: name, value: track) in artists.entries)
                  _ArtistBubble(
                    name: name,
                    track: track,
                    // The artist's page when the catalog has one.
                    onPressed: () => switch (onlineArtistOf(
                      ref.read(providerRegistryProvider),
                      track,
                    )) {
                      final artist? => openOnlineArtist(
                        context,
                        artist.$1.value,
                        artist.$2.value,
                      ),
                      null => openSearchFor(context, ref, name),
                    },
                  ),
              ],
            ),
          ),
        _Section(
          title: AuraStrings.popularNow,
          child: _Shelf(
            children: [
              for (final track in tracks)
                AuraMediaCard(
                  title: track.title,
                  subtitle: canPlayInApp(track)
                      ? track.artistName ?? AuraStrings.unknownArtist
                      : AuraStrings.onlyInOriginal,
                  image: artworkImage(
                    ref,
                    track.artworkUri,
                    alternatives: track.artworkAlternatives,
                  ),
                  onPressed: () => play(track),
                ),
            ],
          ),
        ),
        _Section(
          title: AuraStrings.genres,
          child: _Shelf(
            children: [
              for (final (index, genre) in searchGenres.indexed)
                SizedBox(
                  width: 150,
                  height: MediaQuery.textScalerOf(context).scale(52) + 36,
                  child: GenreTile(
                    genre: genre,
                    index: index,
                    onPressed: () => openSearchFor(context, ref, genre.query),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuraSectionHeader(title: title),
          const SizedBox(height: AuraSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A horizontal row of items with the screen's side insets.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(width: AuraSpacing.md),
            child,
          ],
        ],
      ),
    );
  }
}

/// Swipeable cards: "Хиты недели" (plays the whole list), then the top
/// tracks one by one, each over its own blurred cover. Dots show the page.
class _HeroPager extends StatefulWidget {
  const _HeroPager({
    required this.trackCount,
    required this.featured,
    required this.onPlayAll,
    required this.onPlay,
  });

  final int trackCount;
  final List<Track> featured;
  final VoidCallback? onPlayAll;
  final ValueChanged<Track> onPlay;

  @override
  State<_HeroPager> createState() => _HeroPagerState();
}

class _HeroPagerState extends State<_HeroPager> {
  final _controller = PageController(viewportFraction: 0.9);
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final pages = 1 + widget.featured.length;
    final height = MediaQuery.textScalerOf(context).scale(120) + 110;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: pages,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AuraSpacing.screenHorizontal : 0,
                right: AuraSpacing.md,
              ),
              child: index == 0
                  ? _HeroCard(
                      label: AuraStrings.weeklyHitsLabel,
                      title: AuraStrings.weeklyHits,
                      subtitle: AuraStrings.weeklyHitsSubtitle(
                        widget.trackCount,
                      ),
                      cover: widget.featured.firstOrNull,
                      showCover: false,
                      playLabel: AuraStrings.playPlaylist(
                        AuraStrings.weeklyHits,
                      ),
                      onPlay: widget.onPlayAll,
                    )
                  : _HeroCard(
                      label: AuraStrings.heroRank(index),
                      title: widget.featured[index - 1].title,
                      subtitle:
                          widget.featured[index - 1].artistName ??
                          AuraStrings.unknownArtist,
                      cover: widget.featured[index - 1],
                      showCover: true,
                      playLabel: AuraStrings.playTrack(
                        widget.featured[index - 1].title,
                      ),
                      onPlay: () => widget.onPlay(widget.featured[index - 1]),
                    ),
            ),
          ),
        ),
        if (pages > 1) ...[
          const SizedBox(height: AuraSpacing.md),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages; i++)
                  AnimatedContainer(
                    duration: AuraMotion.fade(context, AuraMotion.normal),
                    curve: AuraMotion.emphasized,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? colors.accent : colors.borderStrong,
                      borderRadius: BorderRadius.circular(AuraRadii.pill),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.showCover,
    required this.playLabel,
    required this.onPlay,
  });

  final String label;
  final String title;
  final String subtitle;

  /// The track whose cover fills the background (and is shown sharp on the
  /// right when [showCover]).
  final Track? cover;
  final bool showCover;
  final String playLabel;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    final text = context.auraText;
    final cover = this.cover;
    final onPlay = this.onPlay;
    final image = cover == null
        ? null
        : artworkImage(
            ref,
            cover.artworkUri,
            alternatives: cover.artworkAlternatives,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadii.xl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AuraArtworkBackdrop(
            image: image,
            placeholderSeed: cover?.title ?? title,
            blur: showCover ? 30 : 0,
          ),
          // Scrim: strongest on the left, where the text is.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.background.withValues(alpha: 0.88),
                  colors.background.withValues(alpha: 0.55),
                  colors.background.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.9),
                radius: 1.1,
                colors: [
                  colors.accent.withValues(alpha: 0.28),
                  colors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: text.caption.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AuraSpacing.xs),
                            Text(
                              title,
                              style: showCover ? text.title1 : text.largeTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AuraSpacing.xxs),
                            Text(
                              subtitle,
                              style: text.subhead.copyWith(
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onPlay != null) ...[
                        const SizedBox(height: AuraSpacing.md),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: colors.accentGlow,
                          ),
                          child: AuraIconButton.filled(
                            icon: CupertinoIcons.play_fill,
                            semanticLabel: playLabel,
                            diameter: 48,
                            iconSize: AuraSizes.iconMd,
                            onPressed: onPlay,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCover && cover != null) ...[
                  const SizedBox(width: AuraSpacing.lg),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AuraRadii.lg),
                      boxShadow: colors.artworkShadow,
                    ),
                    child: AuraArtwork(
                      size: 112,
                      image: image,
                      borderRadius: AuraRadii.lg,
                      placeholderSeed: cover.title,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The weekly top 10 as swipeable columns of four numbered rows.
class _TopChart extends ConsumerWidget {
  const _TopChart({required this.tracks, required this.onPlay});

  final List<Track> tracks;
  final ValueChanged<Track> onPlay;

  static const _perColumn = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    final text = context.auraText;
    final width = MediaQuery.sizeOf(context).width;
    final columnWidth = (width * 0.86).clamp(260.0, 420.0);
    final columns = [
      for (var i = 0; i < tracks.length; i += _perColumn)
        tracks.skip(i).take(_perColumn).toList(),
    ];

    Widget row(int rank, Track track) => AuraPressable(
      onPressed: () => onPlay(track),
      feedback: AuraPressFeedback.highlight,
      borderRadius: BorderRadius.circular(AuraRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                style: text.title2.copyWith(color: colors.accentText),
              ),
            ),
            AuraArtwork(
              size: 52,
              image: artworkImage(
                ref,
                track.artworkUri,
                alternatives: track.artworkAlternatives,
              ),
              placeholderSeed: track.title,
            ),
            const SizedBox(width: AuraSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: text.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    canPlayInApp(track)
                        ? track.artistName ?? AuraStrings.unknownArtist
                        : AuraStrings.onlyInOriginal,
                    style: text.subhead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return _Shelf(
      children: [
        for (final (c, column) in columns.indexed)
          SizedBox(
            width: columnWidth,
            child: Column(
              children: [
                for (final (i, track) in column.indexed)
                  row(c * _perColumn + i + 1, track),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArtistBubble extends ConsumerWidget {
  const _ArtistBubble({
    required this.name,
    required this.track,
    required this.onPressed,
  });

  final String name;

  /// One of the artist's tracks: its cover stands in for a photo.
  final Track track;
  final VoidCallback onPressed;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraPressable(
      onPressed: onPressed,
      semanticLabel: AuraStrings.openArtist(name),
      child: SizedBox(
        width: _size,
        child: Column(
          children: [
            AuraArtwork(
              size: _size,
              shape: AuraArtworkShape.circle,
              image: artworkImage(
                ref,
                track.artworkUri,
                alternatives: track.artworkAlternatives,
              ),
              placeholderSeed: name,
            ),
            const SizedBox(height: AuraSpacing.sm),
            ExcludeSemantics(
              child: Text(
                name,
                style: context.auraText.footnote.copyWith(
                  color: context.auraColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shapes of the hero and the chart while the catalog loads.
class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AuraStrings.loading,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AuraSpacing.screenHorizontal,
          AuraSpacing.xxl,
          AuraSpacing.screenHorizontal,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuraSkeletonBox(
              width: double.infinity,
              height: 230,
              radius: AuraRadii.xl,
            ),
            const SizedBox(height: AuraSpacing.sectionGap),
            const AuraSkeletonBox(width: 160, height: 20),
            const SizedBox(height: AuraSpacing.md),
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: AuraSpacing.sm),
                child: Row(
                  children: [
                    AuraSkeletonBox(
                      width: 52,
                      height: 52,
                      radius: AuraRadii.sm,
                    ),
                    SizedBox(width: AuraSpacing.md),
                    Expanded(child: AuraSkeletonBox(width: 200, height: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
