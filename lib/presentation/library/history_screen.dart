import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/library/mixed_track_list.dart';

/// Recently played tracks, newest first, each once. Kept only on this
/// device; can be cleared.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyPlayedProvider);
    final value = recent.value;
    final store = ref.watch(listeningStoreProvider);

    final List<Widget> slivers;
    if (value == null) {
      slivers = [
        if (recent.error case final error?)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AuraSpacing.screenHorizontal),
              child: InlineErrorText(error: error),
            ),
          )
        else
          const SliverToBoxAdapter(child: LoadingRow()),
      ];
    } else if (value.tracks.isEmpty && value.failure == null) {
      slivers = const [
        LibraryEmptySliver(
          icon: historyIcon,
          title: AuraStrings.historyEmptyTitle,
          message: AuraStrings.historyEmptyMessage,
        ),
      ];
    } else {
      slivers = [
        MixedTrackListSliver(tracks: value.tracks),
        SliverToBoxAdapter(
          child: ResolvedListFooter(
            resolved: value,
            onRetry: () => ref.invalidate(recentlyPlayedProvider),
          ),
        ),
      ];
    }

    return LibraryPage(
      title: AuraStrings.history,
      trailing: store == null || (value?.tracks.isEmpty ?? true)
          ? null
          : AuraIconButton(
              icon: Icons.delete_outline,
              semanticLabel: AuraStrings.clearHistory,
              color: context.auraColors.textSecondary,
              onPressed: () => unawaited(_clear(context, ref)),
            ),
      slivers: slivers,
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: AuraStrings.clearHistory,
      message: AuraStrings.clearHistoryConfirm,
      confirmLabel: AuraStrings.clear,
    );
    if (!confirmed) return;
    final result = await ref.read(listeningStoreProvider)!.clearHistory();
    if (result case Err(:final failure) when context.mounted) {
      await showFailure(context, failure);
    }
  }
}

/// A short failure line for a list that could not load at all.
class InlineErrorText extends StatelessWidget {
  const InlineErrorText({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) =>
      Text(failureText(error).$2, style: context.auraText.subhead);
}
