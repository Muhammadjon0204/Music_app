import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_artist_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/common/play_tracks.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/library/mixed_track_list.dart';
import 'package:music_app/presentation/online/online_tracks.dart';

/// An artist from an online catalog: banner, portrait, followers, their
/// most popular tracks, and the way to their page at the catalog.
class OnlineArtistScreen extends ConsumerWidget {
  const OnlineArtistScreen({
    super.key,
    required this.providerId,
    required this.artistId,
  });

  final ProviderId providerId;
  final ExternalArtistId artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (providerId, artistId);
    final page = ref.watch(onlineArtistProvider(key));
    final value = page.value;
    final error = page.error;

    if (value == null) {
      return LibraryPage(
        title: AuraStrings.artists,
        header: const SizedBox.shrink(),
        slivers: [
          SliverFillRemaining(
            child: error != null && !page.isLoading
                ? Builder(
                    builder: (context) {
                      final (title, message) = failureText(error);
                      return AuraErrorState(
                        title: title,
                        message: message,
                        retryAction: AuraStateAction(
                          label: AuraStrings.retry,
                          onPressed: () =>
                              ref.invalidate(onlineArtistProvider(key)),
                        ),
                      );
                    },
                  )
                : const AuraLoadingState(label: AuraStrings.loading),
          ),
        ],
      );
    }

    final tracks = value.tracks;
    final playable = tracks.where(canPlayInApp).toList();
    return LibraryPage(
      title: value.artist.name,
      header: _ArtistHeader(
        artist: value.artist,
        providerName:
            ref.watch(providerRegistryProvider)[providerId]?.displayName ??
            providerId.value,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpacing.screenHorizontal,
              0,
              AuraSpacing.screenHorizontal,
              AuraSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AuraButton(
                    label: AuraStrings.playAll,
                    icon: CupertinoIcons.play_fill,
                    expand: true,
                    onPressed: playable.isEmpty
                        ? null
                        : () => unawaited(playTracks(ref, playable)),
                  ),
                ),
                const SizedBox(width: AuraSpacing.md),
                Expanded(
                  child: AuraButton(
                    label: AuraStrings.shuffleAll,
                    icon: CupertinoIcons.shuffle,
                    variant: AuraButtonVariant.secondary,
                    expand: true,
                    onPressed: playable.isEmpty
                        ? null
                        : () => unawaited(shuffleTracks(ref, playable)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tracks.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AuraSpacing.md,
                bottom: AuraSpacing.xs,
              ),
              child: AuraSectionHeader(title: AuraStrings.artistPopularTracks),
            ),
          ),
          MixedTrackListSliver(tracks: tracks),
        ],
      ],
    );
  }
}

class _ArtistHeader extends ConsumerWidget {
  const _ArtistHeader({required this.artist, required this.providerName});

  final OnlineArtist artist;
  final String providerName;

  static const _bannerHeight = 220.0;
  static const _portrait = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    final text = context.auraText;
    final portrait = artworkImage(ref, artist.imageUri);
    final banner = artworkImage(ref, artist.coverUri) ?? portrait;
    final pageUrl = artist.pageUrl;
    final followers = artist.followerCount;
    final bio = artist.bio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _bannerHeight + _portrait / 2,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _bannerHeight,
                child: ClipRect(
                  child: AuraArtworkBackdrop(
                    image: banner,
                    placeholderSeed: artist.name,
                    // A portrait stretched into a banner is blurred.
                    blur: artist.coverUri == null ? 24 : 0,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _bannerHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.background.withValues(alpha: 0.1),
                        colors.background,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AuraSpacing.screenHorizontal,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 3),
                    boxShadow: colors.artworkShadow,
                  ),
                  child: AuraArtwork(
                    size: _portrait,
                    image: portrait,
                    shape: AuraArtworkShape.circle,
                    placeholderSeed: artist.name,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.screenHorizontal,
            AuraSpacing.md,
            AuraSpacing.screenHorizontal,
            AuraSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(artist.name, style: text.largeTitle),
              ),
              if (followers != null) ...[
                const SizedBox(height: AuraSpacing.xxs),
                Text(AuraStrings.followers(followers), style: text.subhead),
              ],
              if (bio != null) ...[
                const SizedBox(height: AuraSpacing.sm),
                Text(
                  bio,
                  style: text.subhead,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (pageUrl != null)
                _ProviderLink(
                  label: AuraStrings.openAt(providerName),
                  url: pageUrl,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Открыть на Jamendo ↗": the artist's page at the catalog (credit and
/// backlink).
class _ProviderLink extends ConsumerWidget {
  const _ProviderLink({required this.label, required this.url});

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: AuraPressable(
        onPressed: () => unawaited(_open(context, ref)),
        semanticLabel: label,
        feedback: AuraPressFeedback.opacity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AuraSizes.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: context.auraText.footnote.copyWith(
                    color: colors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpacing.xs),
              Icon(
                CupertinoIcons.arrow_up_right,
                size: AuraSizes.iconSm,
                color: colors.accentText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final opener = ref.read(externalLinkOpenerProvider);
    final opened = await opener?.open(url) ?? false;
    if (!opened && context.mounted) {
      await showMessage(
        context,
        title: AuraStrings.linkOpenFailed,
        message: AuraStrings.failureFeatureUnavailableMessage,
      );
    }
  }
}

/// The artist page for an online [track], when its catalog has one.
OnlineArtistKey? artistPageOf(WidgetRef ref, Track track) =>
    onlineArtistOf(ref.read(providerRegistryProvider), track);
