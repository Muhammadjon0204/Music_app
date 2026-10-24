import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/settings/settings_providers.dart';
import 'package:music_app/data/settings/in_memory_settings_store.dart';
import 'package:music_app/data/settings/sembast_settings_store.dart';
import 'package:music_app/domain/settings/app_settings.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('recent searches', () {
    test('newest first, each once ignoring case, trimmed', () {
      final settings = const AppSettings()
          .withRecentSearch('rock')
          .withRecentSearch(' jazz ')
          .withRecentSearch('ROCK');
      expect(settings.recentSearches, ['ROCK', 'jazz']);
    });

    test('empty queries are not kept', () {
      expect(
        const AppSettings().withRecentSearch('  ').recentSearches,
        isEmpty,
      );
    });

    test('only the newest few are kept', () {
      var settings = const AppSettings();
      for (var i = 0; i < AppSettings.recentSearchLimit + 3; i++) {
        settings = settings.withRecentSearch('q$i');
      }
      expect(settings.recentSearches, hasLength(AppSettings.recentSearchLimit));
      expect(
        settings.recentSearches.first,
        'q${AppSettings.recentSearchLimit + 2}',
      );
    });
  });

  group('sembast store', () {
    test('saves and reads back', () async {
      final db = await newDatabaseFactoryMemory().openDatabase('s.db');
      final store = SembastSettingsStore(db);
      expect((await store.load()).theme, ThemeChoice.neon);

      await store.save(
        const AppSettings(
          theme: ThemeChoice.forest,
          recentSearches: ['lofi', 'jazz'],
        ),
      );
      final again = await SembastSettingsStore(db).load();
      expect(again.theme, ThemeChoice.forest);
      expect(again.recentSearches, ['lofi', 'jazz']);
    });

    test('unknown or broken values fall back one by one', () {
      final settings = SembastSettingsStore.settingsFrom({
        'theme': 'sepia',
        'recentSearches': ['ok', 42, ' ', null],
      });
      expect(settings.theme, ThemeChoice.neon);
      expect(settings.recentSearches, ['ok']);

      final kept = SembastSettingsStore.settingsFrom({
        'theme': 'rose',
        'recentSearches': 'nonsense',
      });
      expect(kept.theme, ThemeChoice.rose);
      expect(kept.recentSearches, isEmpty);
    });
  });

  group('settings controller', () {
    late InMemorySettingsStore store;
    late ProviderContainer container;

    setUp(() {
      store = InMemorySettingsStore();
      container = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(theme: ThemeChoice.midnight),
          ),
        ],
      );
    });

    test('starts from the settings read at launch', () {
      expect(container.read(themeChoiceProvider), ThemeChoice.midnight);
    });

    test('a change applies at once and is saved', () async {
      container.read(settingsProvider.notifier).selectTheme(ThemeChoice.rose);
      expect(container.read(themeChoiceProvider), ThemeChoice.rose);
      await Future<void>.delayed(Duration.zero);
      expect((await store.load()).theme, ThemeChoice.rose);
    });

    test('nothing is saved when nothing changes', () async {
      final controller = container.read(settingsProvider.notifier);
      controller.selectTheme(ThemeChoice.midnight);
      controller.clearRecentSearches();
      await Future<void>.delayed(Duration.zero);
      expect(store.saves, 0);
    });

    test('recent searches can be added, removed and cleared', () {
      final controller = container.read(settingsProvider.notifier)
        ..addRecentSearch('rock')
        ..addRecentSearch('jazz')
        ..removeRecentSearch('rock');
      expect(container.read(settingsProvider).recentSearches, ['jazz']);
      controller.clearRecentSearches();
      expect(container.read(settingsProvider).recentSearches, isEmpty);
    });
  });
}
