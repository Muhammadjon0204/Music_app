import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_providers.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';

/// A saved SoundCloud page in SoundCloud's official embedded player.
///
/// The official widget stays visible (it is the player); AURA lists its
/// sounds and controls it through the official Widget API. It plays on
/// its own, never in AURA's queue (SoundCloud's terms forbid mixing its
/// sounds with other services'), and the two never play at once.
class SoundCloudPlayerScreen extends ConsumerStatefulWidget {
  const SoundCloudPlayerScreen({super.key, required this.url});

  /// The saved link, as passed in the route.
  final String url;

  @override
  ConsumerState<SoundCloudPlayerScreen> createState() =>
      _SoundCloudPlayerScreenState();
}

class _SoundCloudPlayerScreenState
    extends ConsumerState<SoundCloudPlayerScreen> {
  /// Height of the compact official player.
  static const widgetHeight = 166.0;

  late final SoundCloudLink? _link = SoundCloudLink.parse(widget.url);
  late final _player = SoundCloudPlayerController(
    // SoundCloud started: AURA's own player stops.
    onStartedPlaying: () =>
        unawaited(ref.read(playbackControllerProvider)?.pause()),
  );

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _open(Uri url) async {
    final opened =
        await ref.read(externalLinkOpenerProvider)?.open(url) ?? false;
    if (!opened && mounted) {
      await showMessage(
        context,
        title: AuraStrings.linkOpenFailed,
        message: AuraStrings.failureFeatureUnavailableMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    if (link == null) {
      return const LibraryPage(
        title: AuraStrings.notFoundTitle,
        slivers: [
          LibraryEmptySliver(
            icon: CupertinoIcons.question_circle,
            title: AuraStrings.notFoundTitle,
            message: AuraStrings.soundCloudLinkInvalid,
          ),
        ],
      );
    }
    // AURA started: SoundCloud stops.
    ref.listen(
      playbackSnapshotProvider.select((s) => s.value?.playWhenReady ?? false),
      (_, playing) {
        if (playing) _player.pause();
      },
    );
    final info = ref.watch(soundCloudInfoProvider(link)).value;
    final builder = ref.watch(soundCloudWidgetBuilderProvider);
    final text = context.auraText;

    return ListenableBuilder(
      listenable: _player,
      builder: (context, _) => LibraryPage(
        title: info?.title ?? AuraStrings.savedLinks,
        subtitle: info?.author,
        trailing: AuraIconButton(
          icon: CupertinoIcons.arrow_up_right_square,
          semanticLabel: AuraStrings.openOriginal,
          color: context.auraColors.textSecondary,
          onPressed: () => unawaited(_open(link.url)),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AuraSpacing.screenHorizontal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (builder != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AuraRadii.md),
                      child: SizedBox(
                        height: widgetHeight,
                        child: builder(link, _player),
                      ),
                    )
                  else
                    Text(AuraStrings.soundCloudNoPlayer, style: text.body),
                  const SizedBox(height: AuraSpacing.sm),
                  Text(AuraStrings.soundCloudNote, style: text.footnote),
                  if (_player.hasFailed) ...[
                    const SizedBox(height: AuraSpacing.sm),
                    Text(
                      AuraStrings.soundCloudWidgetFailed,
                      style: text.footnote.copyWith(
                        color: context.auraColors.error,
                      ),
                    ),
                  ],
                  if (builder != null) _Controls(player: _player),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: _player.sounds.length,
            itemBuilder: (context, i) => _SoundTile(
              sound: _player.sounds[i],
              isCurrent: i == _player.currentIndex,
              onPressed: _player.isReady ? () => _player.skipTo(i) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final SoundCloudPlayerController player;

  @override
  Widget build(BuildContext context) {
    final ready = player.isReady && !player.hasFailed;
    final multiple = player.sounds.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AuraButton(
              label: player.isPlaying ? AuraStrings.pause : AuraStrings.playAll,
              icon: player.isPlaying
                  ? CupertinoIcons.pause_fill
                  : CupertinoIcons.play_fill,
              expand: true,
              onPressed: ready ? player.toggle : null,
            ),
          ),
          if (multiple) ...[
            const SizedBox(width: AuraSpacing.sm),
            AuraIconButton(
              icon: CupertinoIcons.backward_fill,
              semanticLabel: AuraStrings.previousTrack,
              onPressed: ready ? player.previous : null,
            ),
            AuraIconButton(
              icon: CupertinoIcons.forward_fill,
              semanticLabel: AuraStrings.nextTrack,
              onPressed: ready ? player.next : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _SoundTile extends ConsumerWidget {
  const _SoundTile({
    required this.sound,
    required this.isCurrent,
    required this.onPressed,
  });

  final SoundCloudSound sound;
  final bool isCurrent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = sound.duration;
    final title = sound.title ?? AuraStrings.loading;
    return AuraListTile(
      title: title,
      subtitle: [
        sound.author ?? AuraStrings.unknownArtist,
        if (duration != null) formatDuration(duration),
      ].join(' · '),
      isActive: isCurrent,
      leading: AuraArtwork(
        size: AuraSizes.artworkListTile,
        image: artworkImage(ref, sound.artwork),
        placeholderSeed: title,
      ),
      onPressed: onPressed,
    );
  }
}
