import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/domain/library/library_search.dart';

/// The search query after debouncing. Typing updates it once input pauses,
/// so results are not recomputed on every keystroke.
class SearchQueryController extends Notifier<String> {
  static const debounce = Duration(milliseconds: 300);

  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void onInputChanged(String input) {
    _timer?.cancel();
    final query = input.trim();
    if (query.isEmpty) {
      // Clearing is immediate: no reason to wait.
      state = '';
      return;
    }
    _timer = Timer(debounce, () => state = query);
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

/// Library matches for the current query; null while the query is empty or
/// the library is still loading.
final librarySearchProvider = Provider<LibrarySearchResult?>((ref) {
  final query = ref.watch(searchQueryProvider);
  final library = ref.watch(librarySnapshotProvider).value;
  if (query.isEmpty || library == null) return null;
  return searchLibrary(library, query);
});
