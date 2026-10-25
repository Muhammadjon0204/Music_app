import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/playback/sleep_timer.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// What the sleep timer will do, in one short line.
String sleepTimerStatus(SleepTimerState state) {
  if (state.endOfTrack) return AuraStrings.sleepAfterTrack;
  final endsAt = state.endsAt;
  if (endsAt == null) return AuraStrings.sleepOff;
  String two(int n) => n.toString().padLeft(2, '0');
  return AuraStrings.sleepUntil('${two(endsAt.hour)}:${two(endsAt.minute)}');
}

/// Choices: a duration, the end of the current track (when something is
/// playing), or switching the timer off (when it is on).
Future<void> showSleepTimerSheet(BuildContext context, WidgetRef ref) async {
  final state = ref.read(sleepTimerProvider);
  final hasTrack =
      ref.read(playbackControllerProvider)?.snapshot.currentTrack != null;
  const endOfTrack = Duration.zero;
  const off = Duration(microseconds: -1);
  final choice = await showActionSheet<Duration>(
    context,
    title: AuraStrings.sleepTimer,
    actions: [
      for (final preset in SleepTimerController.presets)
        SheetAction(AuraStrings.sleepIn(preset.inMinutes), preset),
      if (hasTrack) const SheetAction(AuraStrings.sleepAfterTrack, endOfTrack),
      if (state.isActive)
        const SheetAction(AuraStrings.sleepTurnOff, off, destructive: true),
    ],
  );
  if (choice == null) return;
  final timer = ref.read(sleepTimerProvider.notifier);
  switch (choice) {
    case off:
      timer.cancel();
    case endOfTrack:
      timer.stopAtEndOfTrack();
    default:
      timer.startFor(choice);
  }
}
