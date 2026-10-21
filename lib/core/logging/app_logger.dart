import 'dart:developer' as developer;

enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);

  final int value;
}

/// Application logger.
///
/// Never log tokens, API keys, signed or private URLs, file contents, or
/// personal data. Prefer IDs and counts over raw values.
abstract interface class AppLogger {
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Writes to `dart:developer` (visible in DevTools > Logging).
/// Disabled in release builds via [enabled].
final class DeveloperLogger implements AppLogger {
  const DeveloperLogger({required this.enabled});

  final bool enabled;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    developer.log(
      message,
      name: 'aura',
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

extension AppLoggerLevels on AppLogger {
  void debug(String message) => log(LogLevel.debug, message);

  void info(String message) => log(LogLevel.info, message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.warning, message, error: error, stackTrace: stackTrace);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);
}
