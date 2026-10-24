import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/settings/app_settings.dart';

/// [SettingsStore] kept in memory: web, fallback, and tests.
final class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  /// How many times settings were saved.
  int saves = 0;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<Result<void>> save(AppSettings settings) async {
    _settings = settings;
    saves++;
    return const Ok(null);
  }
}
