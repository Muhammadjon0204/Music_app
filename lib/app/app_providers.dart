import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/core/config/app_config.dart';
import 'package:music_app/core/logging/app_logger.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(isReleaseBuild: kReleaseMode),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) =>
      DeveloperLogger(enabled: ref.watch(appConfigProvider).loggingEnabled),
);
