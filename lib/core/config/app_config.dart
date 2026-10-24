enum AppEnvironment { development, production }

/// Build-time configuration.
///
/// Values come from `--dart-define` and are compiled into the app binary,
/// where anyone can extract them. Never pass secrets this way.
final class AppConfig {
  const AppConfig({required this.environment, required this.loggingEnabled});

  factory AppConfig.fromEnvironment({required bool isReleaseBuild}) =>
      AppConfig.parse(
        const String.fromEnvironment('AURA_ENV'),
        isReleaseBuild: isReleaseBuild,
      );

  /// Parses a raw `AURA_ENV` value. An empty value picks the environment
  /// matching the build mode. Unknown values fail fast at startup.
  factory AppConfig.parse(
    String rawEnvironment, {
    required bool isReleaseBuild,
  }) {
    final environment = switch (rawEnvironment) {
      '' =>
        isReleaseBuild ? AppEnvironment.production : AppEnvironment.development,
      'development' => AppEnvironment.development,
      'production' => AppEnvironment.production,
      _ => throw ArgumentError.value(
        rawEnvironment,
        'AURA_ENV',
        'Expected "development" or "production"',
      ),
    };
    return AppConfig(environment: environment, loggingEnabled: !isReleaseBuild);
  }

  final AppEnvironment environment;
  final bool loggingEnabled;

  /// Jamendo API client ID: a public identifier, not a secret (the client
  /// secret is never used). Kept out of Git and passed at build time, e.g.
  /// `--dart-define-from-file=dart_defines.local.json`. Empty when the build
  /// has none; Jamendo is then left out.
  static const jamendoClientId = String.fromEnvironment('JAMENDO_CLIENT_ID');
}
