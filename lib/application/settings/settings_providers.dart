import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/settings/app_settings.dart';

/// Bound at the composition root; null keeps settings for this launch only
/// (tests).
final settingsStoreProvider = Provider<SettingsStore?>((ref) => null);

/// Settings read before the first frame, so the chosen theme shows from the
/// start instead of flashing the default.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// The user's preferences. Changes apply at once and are saved in the
/// background; a failed save is logged and the change still applies.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  void selectTheme(ThemeChoice theme) => _update(state.copyWith(theme: theme));

  void addRecentSearch(String query) => _update(state.withRecentSearch(query));

  void removeRecentSearch(String query) => _update(
    state.copyWith(
      recentSearches: [
        for (final q in state.recentSearches)
          if (q != query) q,
      ],
    ),
  );

  void clearRecentSearches() => _update(state.copyWith(recentSearches: []));

  void _update(AppSettings next) {
    if (_same(next, state)) return;
    state = next;
    final store = ref.read(settingsStoreProvider);
    if (store == null) return;
    unawaited(
      store.save(next).then((result) {
        if (result case Err(:final failure)) {
          ref
              .read(appLoggerProvider)
              .warning('Settings not saved', error: failure);
        }
      }),
    );
  }

  static bool _same(AppSettings a, AppSettings b) =>
      a.theme == b.theme && elementsEqual(a.recentSearches, b.recentSearches);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final themeChoiceProvider = Provider<ThemeChoice>(
  (ref) => ref.watch(settingsProvider.select((s) => s.theme)),
);
