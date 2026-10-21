import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/presentation/dev/design_system_gallery_screen.dart';
import 'package:music_app/presentation/home/home_screen.dart';
import 'package:music_app/presentation/library/library_screen.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/search/search_screen.dart';
import 'package:music_app/presentation/shell/app_shell.dart';

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
                builder: (_, _) => const HomeScreen(),
                routes: [
                  if (kDebugMode)
                    GoRoute(
                      path: 'dev-gallery',
                      builder: (_, _) => const DesignSystemGalleryScreen(),
                    ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (_, state) => SearchScreen(
                  focusRequest: state.uri.queryParameters['focus'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
