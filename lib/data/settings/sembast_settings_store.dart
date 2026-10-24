import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/settings/app_settings.dart';
import 'package:sembast/sembast.dart';

/// Settings in the library's database file, as one record of an extra
/// store (the library records are untouched, so no migration is needed).
final class SembastSettingsStore implements SettingsStore {
  SembastSettingsStore(this._db);

  final Database _db;
  final _record = stringMapStoreFactory.store('settings').record('app');

  @override
  Future<AppSettings> load() async {
    try {
      final map = await _record.get(_db);
      return map == null ? const AppSettings() : settingsFrom(map);
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      await _record.put(_db, {
        'theme': settings.theme.name,
        'recentSearches': settings.recentSearches,
      });
      return const Ok(null);
    } on Object catch (e, stackTrace) {
      return Err(
        StorageFailure(
          debugMessage: 'Settings store: $e',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Unknown or broken values fall back to the defaults one by one.
  static AppSettings settingsFrom(Map<String, Object?> map) {
    final searches = map['recentSearches'];
    return AppSettings(
      theme: ThemeChoice.values.asNameMap()[map['theme']] ?? ThemeChoice.neon,
      recentSearches: searches is List<Object?>
          ? [
              for (final q in searches)
                if (q is String && q.trim().isNotEmpty) q,
            ].take(AppSettings.recentSearchLimit).toList()
          : const [],
    );
  }
}
