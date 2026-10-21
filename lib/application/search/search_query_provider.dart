import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
