import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_artist_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/playback/radio.dart';
import 'package:music_app/application/playback/sleep_timer.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
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
import 'package:music_app/presentation/player/artwork_colors.dart';
import 'package:music_app/presentation/player/play_pause_button.dart';
import 'package:music_app/presentation/player/player_palette.dart';
import 'package:music_app/presentation/player/player_progress.dart';
import 'package:music_app/presentation/player/sleep_timer_sheet.dart';
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
              _TopBar(onClose: close, isSilent: false, showSleepTimer: false),
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

    final details = _Details(
      snapshot: snapshot,
      track: track,
      controller: controller,
    );

    return Scaffold(
      body: SwipeDownToDismiss(
        onDismiss: close,
        child: _PlayerBackground(
          track: track,
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
                                child: _Artwork(
                                  track: track,
                                  size: artSize,
                                  snapshot: snapshot,
                                  controller: controller,
                                ),
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
                            _Artwork(
                              track: track,
                              size: artSize,
                              snapshot: snapshot,
                              controller: controller,
                            ),
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

/// The gradient behind Now Playing, in the colors of the current cover
/// (read once per track and kept for the session), or of its placeholder
/// while the cover loads or when there is none. Cross-fades between tracks.
class _PlayerBackground extends ConsumerStatefulWidget {
  const _PlayerBackground({required this.track, required this.child});

  final Track track;
  final Widget child;

  @override
  ConsumerState<_PlayerBackground> createState() => _PlayerBackgroundState();
}

class _PlayerBackgroundState extends ConsumerState<_PlayerBackground> {
  /// Cover colors by track, for this session only.
  static final _tints = <TrackId, List<Color>>{};
  static const _maxTints = 64;

  TrackId? _requested;

  void _load(TrackId id, ImageProvider<Object> image) {
    _requested = id;
    unawaited(
      loadArtworkTint(image).then((tint) {
        if (tint == null || !mounted) return;
        if (_tints.length >= _maxTints) _tints.remove(_tints.keys.first);
        _tints[id] = tint;
        setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final colors = context.auraColors;
    final image = artworkImage(
      ref,
      track.artworkUri,
      alternatives: track.artworkAlternatives,
    );
    final tint = _tints[track.id];
    if (tint == null && image != null && _requested != track.id) {
      _load(track.id, image);
    }
    final background = nowPlayingBackground(
      tint ?? AuraArtwork.placeholderGradient(track.title, colors),
      colors,
    );
    return AnimatedContainer(
      duration: AuraMotion.fade(context, AuraMotion.slow),
      curve: AuraMotion.standard,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: background,
          stops: nowPlayingBackgroundStops,
        ),
      ),
      child: widget.child,
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onClose,
    required this.isSilent,
    this.showSleepTimer = true,
  });

  final VoidCallback onClose;
  final bool isSilent;

  /// The sleep timer button on the right; hidden when nothing plays.
  final bool showSleepTimer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleep = ref.watch(sleepTimerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
      child: Row(
        children: [
          AuraIconButton(
            icon: CupertinoIcons.chevron_down,
            semanticLabel: AuraStrings.closePlayer,
            onPressed: onClose,
          ),
          Expanded(
            child: Center(
              child: isSilent
                  ? const _SilentChip()
                  : ref.watch(radioProvider) != null
                  ? const _RadioChip()
                  : null,
            ),
          ),
          if (showSleepTimer)
            AuraIconButton(
              icon: sleep.isActive
                  ? CupertinoIcons.moon_zzz_fill
                  : CupertinoIcons.moon_zzz,
              semanticLabel:
                  '${AuraStrings.sleepTimer}: ${sleepTimerStatus(sleep)}',
              toggled: sleep.isActive,
              color: sleep.isActive
                  ? context.auraColors.accentText
                  : context.auraColors.textSecondary,
              onPressed: () => unawaited(showSleepTimerSheet(context, ref)),
            )
          else
            const SizedBox(width: AuraSizes.minTouchTarget),
        ],
      ),
    );
  }
}

/// "Радио" while a radio plays: the queue keeps growing by itself.
class _RadioChip extends StatelessWidget {
  const _RadioChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.sm,
        vertical: AuraSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.background.withValues(
          alpha: nowPlayingLabelBackdropAlpha,
        ),
        borderRadius: BorderRadius.circular(AuraRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.antenna_radiowaves_left_right,
            size: AuraSizes.iconSm,
            color: colors.accentText,
          ),
          const SizedBox(width: AuraSpacing.xs),
          Text(
            AuraStrings.radio,
            style: context.auraText.caption.copyWith(
              color: colors.accentText,
              fontWeight: FontWeight.w600,
            ),
          ),
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

/// The cover. It eases back a little while paused, and a horizontal swipe
/// on it plays the next or previous track (the buttons below do the same,
/// for VoiceOver).
class _Artwork extends ConsumerWidget {
  const _Artwork({
    required this.track,
    required this.size,
    required this.snapshot,
    required this.controller,
  });

  final Track track;
  final double size;
  final PlaybackSnapshot snapshot;
  final PlaybackController controller;

  /// Scale of the cover while paused.
  static const pausedScale = 0.86;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.auraColors;
    final reduced = AuraMotion.isReduced(context);
    final playing = snapshot.playWhenReady;
    return _SwipeToSkip(
      width: size,
      onNext: snapshot.hasNext
          ? () => unawaited(controller.skipToNext())
          : null,
      onPrevious: () => unawaited(controller.skipToPrevious()),
      child: AnimatedScale(
        scale: playing || reduced ? 1 : pausedScale,
        duration: AuraMotion.slow,
        curve: AuraMotion.emphasized,
        child: HeroMode(
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
              child: AnimatedContainer(
                key: ValueKey(track.id),
                duration: AuraMotion.slow,
                curve: AuraMotion.emphasized,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AuraRadii.xl),
                  // A deeper shadow while playing: the cover "lifts".
                  boxShadow: [
                    BoxShadow(
                      color: colors.background.withValues(
                        alpha: playing ? 0.7 : 0.4,
                      ),
                      blurRadius: playing ? 48 : 24,
                      offset: Offset(0, playing ? 24 : 12),
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
                  borderRadius: AuraRadii.xl,
                  placeholderSeed: track.title,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the cover follow a horizontal drag; far enough (a quarter of its
/// width) or fast enough, it changes the track with a light haptic, and
/// springs back either way.
class _SwipeToSkip extends StatefulWidget {
  const _SwipeToSkip({
    required this.width,
    required this.onNext,
    required this.onPrevious,
    required this.child,
  });

  final double width;

  /// Null when there is no next track: the cover only springs back.
  final VoidCallback? onNext;
  final VoidCallback onPrevious;
  final Widget child;

  /// Fling speed (logical px/s) that changes the track on its own.
  static const flingVelocity = 300.0;

  @override
  State<_SwipeToSkip> createState() => _SwipeToSkipState();
}

class _SwipeToSkipState extends State<_SwipeToSkip> {
  double _offset = 0;
  bool _dragging = false;

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final far = widget.width * 0.25;
    final VoidCallback? action;
    if (velocity < -_SwipeToSkip.flingVelocity || _offset < -far) {
      action = widget.onNext;
    } else if (velocity > _SwipeToSkip.flingVelocity || _offset > far) {
      action = widget.onPrevious;
    } else {
      action = null;
    }
    if (action != null) {
      unawaited(HapticFeedback.lightImpact());
      action();
    }
    setState(() {
      _offset = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AuraMotion.isReduced(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) => setState(
        () => _offset = (_offset + details.delta.dx).clamp(
          -widget.width,
          widget.width,
        ),
      ),
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => setState(() {
        _offset = 0;
        _dragging = false;
      }),
      child: AnimatedContainer(
        duration: _dragging || reduced ? Duration.zero : AuraMotion.normal,
        curve: AuraMotion.emphasized,
        // Follows the finger at half speed, so it feels held back.
        transform: Matrix4.translationValues(reduced ? 0 : _offset / 2, 0, 0),
        child: widget.child,
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
                    _ArtistName(track: track),
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
        _BottomRow(snapshot: snapshot),
      ],
    );
  }
}

/// The artist's name; for an online track with an artist page it opens
/// that page (in the Home tab, closing the player).
class _ArtistName extends ConsumerWidget {
  const _ArtistName({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = track.artistName ?? AuraStrings.unknownArtist;
    final artist = onlineArtistOf(ref.watch(providerRegistryProvider), track);
    final label = Text(
      name,
      style: context.auraText.subhead.copyWith(
        color: artist == null ? null : context.auraColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (artist == null) return label;
    return AuraPressable(
      onPressed: () => context.go(
        AppRoutes.onlineArtist(
          AppRoutes.home,
          artist.$1.value,
          artist.$2.value,
        ),
      ),
      semanticLabel: AuraStrings.openArtist(name),
      feedback: AuraPressFeedback.opacity,
      // The label says it all; the name inside is not read twice.
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AuraSizes.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: label),
              const SizedBox(width: AuraSpacing.xxs),
              Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: context.auraColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
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
          haptic: true,
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
          haptic: true,
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

/// "Далее" with the next track's title in the middle, the queue button on the right.
/// Both open the queue.
class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.snapshot});

  final PlaybackSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final index = snapshot.currentIndex;
    final next = index != null && index + 1 < snapshot.queue.length
        ? snapshot.queue[index + 1]
        : null;
    void openQueue() => unawaited(context.push(AppRoutes.queue));

    return Row(
      children: [
        const SizedBox(width: AuraSizes.minTouchTarget),
        Expanded(
          child: Center(
            child: next == null
                ? const SizedBox.shrink()
                : AuraPressable(
                    onPressed: openQueue,
                    semanticLabel: AuraStrings.upNextTrack(next.title),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AuraSizes.minTouchTarget,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AuraRadii.pill),
                      ),
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AuraStrings.upNext,
                              style: context.auraText.footnote.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AuraSpacing.sm),
                            Flexible(
                              child: Text(
                                next.title,
                                style: context.auraText.footnote.copyWith(
                                  color: colors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        AuraIconButton(
          icon: CupertinoIcons.list_bullet,
          semanticLabel: AuraStrings.queue,
          color: colors.textSecondary,
          onPressed: openQueue,
        ),
      ],
    );
  }
}
