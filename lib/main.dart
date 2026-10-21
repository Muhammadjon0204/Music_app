import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/app/app_providers.dart';
import 'package:music_app/core/logging/app_logger.dart';

void main() {
  final container = ProviderContainer();
  final logger = container.read(appLoggerProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.error(
      'Unhandled Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.error(
      'Unhandled asynchronous error',
      error: error,
      stackTrace: stackTrace,
    );
    // In debug builds, also let the engine print it to the console.
    return !kDebugMode;
  };

  runApp(
    UncontrolledProviderScope(container: container, child: const AuraApp()),
  );
}
