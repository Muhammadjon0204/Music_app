import 'package:music_app/core/error/result.dart';

/// The color theme the user picked. The default is the neon theme of the
/// design reference.
enum ThemeChoice { neon, midnight, rose, forest }

/// Preferences kept across launches. Only choices the user made; nothing
/// about online tracks.
final class AppSettings {
  const AppSettings({
    this.theme = ThemeChoice.neon,
    this.recentSearches = const [],
  });

  /// At most this many recent searches are kept.
  static const recentSearchLimit = 8;

  final ThemeChoice theme;

  /// Newest first, without duplicates (compared ignoring case).
  final List<String> recentSearches;

  AppSettings copyWith({ThemeChoice? theme, List<String>? recentSearches}) =>
      AppSettings(
        theme: theme ?? this.theme,
        recentSearches: recentSearches ?? this.recentSearches,
      );

  /// [query] moved to the front of the recent searches.
  AppSettings withRecentSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return this;
    final key = trimmed.toLowerCase();
    return copyWith(
      recentSearches: [
        trimmed,
        ...recentSearches.where((q) => q.toLowerCase() != key),
      ].take(recentSearchLimit).toList(),
    );
  }
}

abstract interface class SettingsStore {
  /// Never fails: unreadable settings are the defaults.
  Future<AppSettings> load();

  Future<Result<void>> save(AppSettings settings);
}
