import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/player/mini_player_bar.dart';
import 'package:music_app/presentation/player/player_progress.dart';

/// Tabs with independent navigation stacks, plus the mini player slot.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    AuraTabItem(
      icon: CupertinoIcons.house,
      selectedIcon: CupertinoIcons.house_fill,
      label: AuraStrings.tabHome,
    ),
    AuraTabItem(
      icon: CupertinoIcons.search,
      selectedIcon: CupertinoIcons.search,
      label: AuraStrings.tabSearch,
    ),
    AuraTabItem(
      icon: CupertinoIcons.music_albums,
      selectedIcon: CupertinoIcons.music_albums_fill,
      label: AuraStrings.tabLibrary,
    ),
    AuraTabItem(
      icon: CupertinoIcons.gear,
      selectedIcon: CupertinoIcons.gear_solid,
      label: AuraStrings.settings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackSnapshotProvider).value;
    final controller = ref.watch(playbackControllerProvider);
    final track = snapshot?.currentTrack;
    // Follows intent, so "pause" works while a stream is still buffering.
    final isPlaying = snapshot?.playWhenReady ?? false;

    return Scaffold(
      body: navigationShell,
      // Bars keep a bounded height at very large text sizes, as on iOS.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track != null && snapshot != null && controller != null)
              SafeArea(
                top: false,
                bottom: false,
                child: MiniPlayerBar(
                  track: track,
                  isPlaying: isPlaying,
                  isWaiting: snapshot.isWaiting,
                  onTogglePlay: () => unawaited(
                    isPlaying ? controller.pause() : controller.play(),
                  ),
                  onNext: snapshot.hasNext
                      ? () => unawaited(controller.skipToNext())
                      : null,
                  onOpen: () => unawaited(context.push(AppRoutes.nowPlaying)),
                  progress: MiniPlayerProgress(
                    duration: snapshot.duration ?? track.duration,
                  ),
                ),
              ),
            AuraTabBar(
              items: _tabs,
              currentIndex: navigationShell.currentIndex,
              // Re-tapping the current tab returns to its root, as on iOS.
              onSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
