import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/home/greeting.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final now = ref.watch(clockProvider)();
    final value = feed.value;
    final error = feed.error;

    final List<Widget> body;
    if (value != null && value.isEmpty) {
      // State views get the remaining height directly (they scroll
      // themselves at large text sizes) rather than being measured.
      body = const [
        SliverFillRemaining(
          child: AuraEmptyState(
            icon: CupertinoIcons.music_note_list,
            title: AuraStrings.homeEmptyTitle,
            message: AuraStrings.homeEmptyMessage,
          ),
        ),
      ];
    } else if (value != null) {
      body = [SliverList.list(children: _sections(value))];
    } else if (error != null && !feed.isLoading) {
      final (title, message) = failureText(error);
      body = [
        SliverFillRemaining(
          child: AuraErrorState(
            title: title,
            message: message,
            retryAction: AuraStateAction(
              label: AuraStrings.retry,
              onPressed: () => ref.invalidate(homeFeedProvider),
            ),
          ),
        ),
      ];
    } else {
      body = const [SliverToBoxAdapter(child: _HomeSkeleton())];
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(greeting: greetingFor(now))),
              if (value?.isDemo ?? false)
                const SliverToBoxAdapter(child: _DemoBadge()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpacing.screenHorizontal,
                    AuraSpacing.lg,
                    AuraSpacing.screenHorizontal,
                    0,
                  ),
                  child: AuraSearchField.button(
                    placeholder: AuraStrings.searchPlaceholder,
                    onPressed: () => context.go(
                      AppRoutes.searchFocused(
                        '${DateTime.now().microsecondsSinceEpoch}',
                      ),
                    ),
                  ),
                ),
              ),
              ...body,
              const SliverToBoxAdapter(
                child: SizedBox(height: AuraSpacing.xxxl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _maxCarouselItems = 10;

  List<Widget> _sections(HomeFeed feed) {
    Widget albumCard(Album album) => AuraMediaCard(
      title: album.title,
      subtitle: album.artistName ?? AuraStrings.unknownArtist,
    );
    Widget playlistCard(Playlist playlist) => AuraMediaCard(
      title: playlist.name,
      subtitle: AuraStrings.trackCount(playlist.trackIds.length),
    );

    return [
      if (feed.featured case final featured?)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.screenHorizontal,
            AuraSpacing.xxl,
            AuraSpacing.screenHorizontal,
            0,
          ),
          child: _FeaturedBanner(playlist: featured),
        ),
      if (feed.recentlyPlayed.isNotEmpty)
        _Carousel(
          title: AuraStrings.homeRecentlyPlayed,
          cards: feed.recentlyPlayed.take(_maxCarouselItems).map(albumCard),
        ),
      if (feed.albums.isNotEmpty)
        _Carousel(
          title: AuraStrings.homeAlbums,
          cards: feed.albums.take(_maxCarouselItems).map(albumCard),
        ),
      if (feed.playlists.isNotEmpty)
        _Carousel(
          title: AuraStrings.homePlaylists,
          cards: feed.playlists.take(_maxCarouselItems).map(playlistCard),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenHorizontal,
        AuraSpacing.lg,
        AuraSpacing.sm,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(greeting, style: text.largeTitle),
                ),
                const SizedBox(height: AuraSpacing.xxs),
                Text(AuraStrings.homeSubtitle, style: text.subhead),
              ],
            ),
          ),
          if (kDebugMode)
            AuraIconButton(
              icon: CupertinoIcons.paintbrush,
              semanticLabel: AuraStrings.devGallery,
              color: context.auraColors.textSecondary,
              onPressed: () => unawaited(context.push(AppRoutes.devGallery)),
            ),
        ],
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenHorizontal,
        AuraSpacing.md,
        AuraSpacing.screenHorizontal,
        0,
      ),
      child: Semantics(
        label: '${AuraStrings.demoBadge}. ${AuraStrings.demoBadgeHint}',
        child: ExcludeSemantics(
          // Wraps onto two lines at large text sizes instead of overflowing.
          child: Wrap(
            spacing: AuraSpacing.sm,
            runSpacing: AuraSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.sm,
                  vertical: AuraSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.accentText),
                  borderRadius: BorderRadius.circular(AuraRadii.pill),
                ),
                child: Text(
                  AuraStrings.demoBadge,
                  style: text.caption.copyWith(
                    color: colors.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(AuraStrings.demoBadgeHint, style: text.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuraRadii.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AuraArtwork.placeholderGradient(playlist.name, colors),
          ),
        ),
        // Scrim keeps the text readable on any gradient.
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.background.withValues(alpha: 0),
                colors.background.withValues(alpha: 0.75),
              ],
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AuraSpacing.lg),
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.name,
                        style: text.title1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AuraSpacing.xxs),
                      Text(
                        '${AuraStrings.playlist} · '
                        '${AuraStrings.trackCount(playlist.trackIds.length)}',
                        style: text.subhead.copyWith(color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.title, required this.cards});

  final String title;
  final Iterable<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraSectionHeader(title: title),
          const SizedBox(height: AuraSpacing.md),
          // At most a few items, so a non-lazy row is fine and lets the row
          // height follow the system text size.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.screenHorizontal,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, card) in cards.indexed) ...[
                  if (index > 0) const SizedBox(width: AuraSpacing.md),
                  card,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

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
              height: 160,
              radius: AuraRadii.lg,
            ),
            const SizedBox(height: AuraSpacing.sectionGap),
            const AuraSkeletonBox(width: 180, height: 18),
            const SizedBox(height: AuraSpacing.md),
            SizedBox(
              height: AuraSizes.artworkCard,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: AuraSpacing.md),
                    const AuraSkeletonBox(
                      width: AuraSizes.artworkCard,
                      height: AuraSizes.artworkCard,
                      radius: AuraRadii.md,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
