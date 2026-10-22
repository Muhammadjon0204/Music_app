import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

/// Opens an album, artist or playlist in the current tab.
void openDetail(BuildContext context, DetailKind kind, String id) {
  final segments = GoRouterState.of(context).uri.pathSegments;
  final tab = segments.isEmpty ? '' : segments.first;
  final root = const {'home', 'search', 'library'}.contains(tab)
      ? '/$tab'
      : AppRoutes.library;
  unawaited(context.push(AppRoutes.detail(root, kind, id)));
}

/// Back, or to the Library root when there is nothing to go back to (e.g.
/// the page was opened directly from a link).
void goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.library);
  }
}
