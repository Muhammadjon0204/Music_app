import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Seekable progress. The only part of Now Playing that rebuilds on every
/// position tick.
class PlayerProgress extends ConsumerWidget {
  const PlayerProgress({super.key, required this.duration});

  final Duration? duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final controller = ref.watch(playbackControllerProvider);
    return AuraProgressBar(
      position: position,
      duration: duration,
      semanticLabel: AuraStrings.playbackPosition,
      semanticValue: (position, total) => AuraStrings.positionOf(
        formatDuration(position),
        formatDuration(total),
      ),
      onSeek: controller == null
          ? null
          : (target) => unawaited(controller.seek(target)),
    );
  }
}

/// Thin, non-interactive progress line for the mini player.
class MiniPlayerProgress extends ConsumerWidget {
  const MiniPlayerProgress({super.key, required this.duration});

  final Duration? duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final total = duration ?? Duration.zero;
    final fraction = total == Duration.zero
        ? 0.0
        : (position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    final colors = context.auraColors;
    return ExcludeSemantics(
      child: SizedBox(
        height: 2,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: ColoredBox(color: colors.accent),
          ),
        ),
      ),
    );
  }
}
