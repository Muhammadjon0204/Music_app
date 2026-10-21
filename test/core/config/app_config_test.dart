import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('empty value follows the build mode', () {
      expect(
        AppConfig.parse('', isReleaseBuild: false).environment,
        AppEnvironment.development,
      );
      expect(
        AppConfig.parse('', isReleaseBuild: true).environment,
        AppEnvironment.production,
      );
    });

    test('explicit value wins over the build mode', () {
      expect(
        AppConfig.parse('production', isReleaseBuild: false).environment,
        AppEnvironment.production,
      );
    });

    test('logging is disabled in release builds', () {
      expect(AppConfig.parse('', isReleaseBuild: true).loggingEnabled, isFalse);
      expect(AppConfig.parse('', isReleaseBuild: false).loggingEnabled, isTrue);
    });

    test('unknown value fails fast', () {
      expect(
        () => AppConfig.parse('staging', isReleaseBuild: false),
        throwsArgumentError,
      );
    });
  });
}
