import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

/// Opens the Search tab already searching for [query] (an artist or a
/// genre picked elsewhere), and remembers it as a recent search.
void openSearchFor(BuildContext context, WidgetRef ref, String query) {
  ref.read(searchQueryProvider.notifier).searchNow(query);
  ref.read(settingsProvider.notifier).addRecentSearch(query);
  context.go(AppRoutes.search);
}
