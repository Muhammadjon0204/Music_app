import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/online/online_tracks.dart';
import 'package:music_app/presentation/player/play_pause_button.dart';
import 'package:music_app/presentation/player/player_palette.dart';
import 'package:music_app/presentation/player/player_progress.dart';
import 'package:music_app/presentation/player/swipe_down_to_dismiss.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  static const _horizontalPadding = 28.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot =
        ref.watch(playbackSnapshotProvider).value ?? PlaybackSnapshot.initial;
    final controller = ref.watch(playbackControllerProvider);
    final isSilent = ref.watch(isSilentPlaybackProvider);
    final track = snapshot.currentTrack;

    void close() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    }

    if (track == null || controller == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onClose: close, isSilent: false),
              const Expanded(
                child: AuraEmptyState(
                  icon: CupertinoIcons.music_note,
                  title: AuraStrings.nothingPlayingTitle,
                  message: AuraStrings.nothingPlayingMessage,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final colors = context.auraColors;
    final background = nowPlayingBackground(
      AuraArtwork.placeholderGradient(track.title, colors),
      colors,
    );
    final details = _Details(
      snapshot: snapshot,
      track: track,
      controller: controller,
    );

    return Scaffold(
      body: SwipeDownToDismiss(
        onDismiss: close,
        child: AnimatedContainer(
          duration: AuraMotion.fade(context, AuraMotion.slow),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: background,
              stops: nowPlayingBackgroundStops,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape =
                    constraints.maxWidth > constraints.maxHeight * 1.2;
                final topBar = _TopBar(onClose: close, isSilent: isSilent);

                if (landscape) {
                  final artSize = math.max(
                    96.0,
                    math.min(
                      constraints.maxHeight - 88,
                      constraints.maxWidth * 0.4,
                    ),
                  );
                  return Column(
                    children: [
                      topBar,
                      Expanded(
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpacing.xl,
                              ),
                              child: Center(
                                child: _Artwork(track: track, size: artSize),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  right: AuraSpacing.xl,
                                  bottom: AuraSpacing.lg,
                                ),
                                child: details,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final artSize = math.min(
                  420.0,
                  math.max(
                    120.0,
                    math.min(
                      constraints.maxWidth - 2 * _horizontalPadding,
                      constraints.maxHeight * 0.42,
                    ),
                  ),
                );
                return Column(
                  children: [
                    topBar,
                    Expanded(
                      // Scrolls only when the content does not fit (large
                      // text); otherwise the swipe-down gesture gets the drag.
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: _horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: AuraSpacing.lg),
                            _Artwork(track: track, size: artSize),
                            const SizedBox(height: AuraSpacing.xxl),
                            details,
                            const SizedBox(height: AuraSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.isSilent});

  final VoidCallback onClose;
  final bool isSilent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
      child: Row(
        children: [
          AuraIconButton(
            icon: CupertinoIcons.chevron_down,
            semanticLabel: AuraStrings.closePlayer,
            onPressed: onClose,
          ),
          Expanded(child: Center(child: isSilent ? const _SilentChip() : null)),
          const SizedBox(width: AuraSizes.minTouchTarget),
        ],
      ),
    );
  }
}

class _SilentChip extends StatelessWidget {
  const _SilentChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return Semantics(
      label: AuraStrings.silentPlaybackHint,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpacing.sm,
            vertical: AuraSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.background.withValues(
              alpha: nowPlayingLabelBackdropAlpha,
            ),
            border: Border.all(color: colors.accentText),
            borderRadius: BorderRadius.circular(AuraRadii.pill),
          ),
          child: Text(
            AuraStrings.silentPlayback,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.auraText.caption.copyWith(
              color: colors.accentText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends ConsumerWidget {
  const _Artwork({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    final reduced = AuraMotion.isReduced(context);
    return HeroMode(
      enabled: !reduced,
      child: Hero(
        tag: playerArtworkHeroTag,
        child: AnimatedSwitcher(
          duration: AuraMotion.fade(context, AuraMotion.normal),
          switchInCurve: AuraMotion.standard,
          transitionBuilder: (child, animation) {
            final faded = FadeTransition(opacity: animation, child: child);
            if (reduced) return faded;
            return ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: faded,
            );
          },
          child: DecoratedBox(
            key: ValueKey(track.id),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AuraRadii.lg),
              boxShadow: [
                BoxShadow(
                  color: colors.background.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: AuraArtwork(
              size: size,
              image: artworkImage(
                ref,
                track.artworkUri,
                alternatives: track.artworkAlternatives,
              ),
              borderRadius: AuraRadii.lg,
              placeholderSeed: track.title,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Открыть оригинал ↗" for online tracks: a way to the original page.
/// Catalogs whose terms require credit (Jamendo) are named instead:
/// "Источник: Jamendo ↗". Nothing for local music.
class _SourceLink extends ConsumerWidget {
  const _SourceLink({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = onlineSourceOf(track);
    if (source == null) return const SizedBox.shrink();
    final colors = context.auraColors;
    final provider = ref.watch(providerRegistryProvider)[source.providerId];
    final text = provider is AttributionRequiredProvider
        ? AuraStrings.sourceCredit(provider.displayName)
        : AuraStrings.openOriginal;
    final label = Text(
      text,
      style: context.auraText.footnote.copyWith(color: colors.textSecondary),
    );
    if (!source.canOpenExternally) {
      return Padding(
        padding: const EdgeInsets.only(top: AuraSpacing.xs),
        child: label,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: AuraPressable(
        onPressed: () => unawaited(openOriginal(context, ref, track)),
        semanticLabel: text,
        feedback: AuraPressFeedback.opacity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AuraSizes.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: AuraSpacing.xs),
              Icon(
                CupertinoIcons.arrow_up_right,
                size: AuraSizes.iconSm,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Heart for tracks in the library; hidden for anything else.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider).value;
    // Library tracks, and online tracks (saved as a reference only).
    final canFavorite =
        library != null &&
        (library.contains(track.id) || providerRefOf(track.id) != null);
    if (!canFavorite) return const SizedBox.shrink();
    final favorite = library.isFavorite(track.id);
    final colors = context.auraColors;
    return AuraIconButton(
      icon: favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
      semanticLabel: AuraStrings.favoriteTrack,
      toggled: favorite,
      color: favorite ? colors.accentText : colors.textSecondary,
      onPressed: () async {
        final result = await ref
            .read(libraryRepositoryProvider)
            .setFavorite(track.id, favorite: !favorite);
        if (result case Err(:final failure) when context.mounted) {
          await showFailure(context, failure);
        }
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.snapshot,
    required this.track,
    required this.controller,
  });

  final PlaybackSnapshot snapshot;
  final Track track;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final failure = snapshot.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: AuraMotion.fade(context, AuraMotion.normal),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: Row(
            key: ValueKey(track.id),
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: text.title2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AuraSpacing.xxs),
                    Text(
                      track.artistName ?? AuraStrings.unknownArtist,
                      style: text.subhead,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _FavoriteButton(track: track),
            ],
          ),
        ),
        _SourceLink(track: track),
        if (failure != null) ...[
          const SizedBox(height: AuraSpacing.sm),
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: AuraSizes.iconSm,
                color: colors.error,
              ),
              const SizedBox(width: AuraSpacing.xs),
              Expanded(
                child: Text(
                  failureText(failure).$1,
                  style: text.footnote.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpacing.xxs),
          Text(failureText(failure).$2, style: text.footnote),
          if (snapshot.status == PlaybackStatus.failed) ...[
            const SizedBox(height: AuraSpacing.sm),
            // One more attempt, from where the track stopped. "Next"
            // below moves on instead. Never retried automatically.
            Align(
              alignment: Alignment.centerLeft,
              child: AuraButton(
                label: AuraStrings.retry,
                icon: CupertinoIcons.arrow_clockwise,
                variant: AuraButtonVariant.secondary,
                onPressed: () => unawaited(controller.play()),
              ),
            ),
          ],
        ],
        const SizedBox(height: AuraSpacing.lg),
        PlayerProgress(duration: snapshot.duration ?? track.duration),
        const SizedBox(height: AuraSpacing.sm),
        _Controls(snapshot: snapshot, controller: controller),
        const SizedBox(height: AuraSpacing.lg),
        Center(
          child: AuraButton(
            label: AuraStrings.queue,
            icon: CupertinoIcons.list_bullet,
            variant: AuraButtonVariant.secondary,
            onPressed: () => unawaited(context.push(AppRoutes.queue)),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.snapshot, required this.controller});

  final PlaybackSnapshot snapshot;
  final PlaybackController controller;

  static PlaybackRepeatMode _nextRepeat(PlaybackRepeatMode mode) =>
      switch (mode) {
        PlaybackRepeatMode.off => PlaybackRepeatMode.all,
        PlaybackRepeatMode.all => PlaybackRepeatMode.one,
        PlaybackRepeatMode.one => PlaybackRepeatMode.off,
      };

  @override
  Widget build(BuildContext context) {
    final repeat = snapshot.repeatMode;
    // Follows intent, so "pause" works while a stream is still buffering.
    final playing = snapshot.playWhenReady;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AuraToggleButton(
          icon: CupertinoIcons.shuffle,
          semanticLabel: AuraStrings.shuffle,
          isOn: snapshot.shuffleEnabled,
          onPressed: () =>
              unawaited(controller.setShuffleEnabled(!snapshot.shuffleEnabled)),
        ),
        AuraIconButton(
          icon: CupertinoIcons.backward_fill,
          semanticLabel: AuraStrings.previousTrack,
          iconSize: 30,
          onPressed: () => unawaited(controller.skipToPrevious()),
        ),
        PlayPauseButton(
          isPlaying: playing,
          isWaiting: snapshot.isWaiting,
          diameter: AuraSizes.playButtonLarge,
          iconSize: 30,
          onPressed: () =>
              unawaited(playing ? controller.pause() : controller.play()),
        ),
        AuraIconButton(
          icon: CupertinoIcons.forward_fill,
          semanticLabel: AuraStrings.nextTrack,
          iconSize: 30,
          onPressed: snapshot.hasNext
              ? () => unawaited(controller.skipToNext())
              : null,
        ),
        AuraToggleButton(
          icon: repeat == PlaybackRepeatMode.one
              ? CupertinoIcons.repeat_1
              : CupertinoIcons.repeat,
          semanticLabel: switch (repeat) {
            PlaybackRepeatMode.off => AuraStrings.repeatOff,
            PlaybackRepeatMode.all => AuraStrings.repeatAll,
            PlaybackRepeatMode.one => AuraStrings.repeatOne,
          },
          isOn: repeat != PlaybackRepeatMode.off,
          onPressed: () =>
              unawaited(controller.setRepeatMode(_nextRepeat(repeat))),
        ),
      ],
    );
  }
}
