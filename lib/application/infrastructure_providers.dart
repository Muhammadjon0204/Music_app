import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/core/config/app_config.dart';
import 'package:music_app/core/logging/app_logger.dart';

// Same constant Flutter's kReleaseMode uses, without importing Flutter here.
const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(isReleaseBuild: _isReleaseBuild),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) =>
      DeveloperLogger(enabled: ref.watch(appConfigProvider).loggingEnabled),
);

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
