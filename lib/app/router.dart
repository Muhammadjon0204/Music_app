import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/dev/design_system_gallery_screen.dart';
import 'package:music_app/presentation/home/home_screen.dart';
import 'package:music_app/presentation/library/library_screen.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/player/now_playing_screen.dart';
import 'package:music_app/presentation/player/queue_screen.dart';
import 'package:music_app/presentation/search/search_screen.dart';
import 'package:music_app/presentation/shell/app_shell.dart';

/// go_router 18 only recognises `MaterialApp` from the separate
/// `material_ui` package; with Flutter's own MaterialApp it falls back to
/// pages without any transition or iOS swipe-back. Building pages
/// explicitly applies the app's page transitions theme.
Page<void> _page(GoRouterState state, Widget child) => MaterialPage<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  restorationId: state.pageKey.value,
  child: child,
);

Page<void> _sheetPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name ?? state.path,
      fullscreenDialog: true,
      transitionDuration: AuraMotion.slow,
      reverseTransitionDuration: AuraMotion.normal,
      transitionsBuilder: auraSheetTransition,
      child: child,
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    // Unknown locations go Home instead of showing an internal error page.
    onException: (_, _, router) => router.go(AppRoutes.home),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (_, state) => _page(state, const HomeScreen()),
                routes: [
                  if (kDebugMode)
                    GoRoute(
                      path: 'dev-gallery',
                      pageBuilder: (_, state) =>
                          _page(state, const DesignSystemGalleryScreen()),
                    ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                pageBuilder: (_, state) => _page(
                  state,
                  SearchScreen(
                    focusRequest: state.uri.queryParameters['focus'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                pageBuilder: (_, state) => _page(state, const LibraryScreen()),
              ),
            ],
          ),
        ],
      ),
      // Top-level, so the player covers the tabs.
      GoRoute(
        path: AppRoutes.nowPlaying,
        pageBuilder: (_, state) => _sheetPage(state, const NowPlayingScreen()),
        routes: [
          GoRoute(
            path: 'queue',
            pageBuilder: (_, state) => _page(state, const QueueScreen()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
