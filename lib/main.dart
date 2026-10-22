import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/data/demo/demo_playback_controller.dart';

void main() {
  // Composition root: binds implementations to application contracts.
  final container = ProviderContainer(
    overrides: [
      // DEMO DATA until the local library exists (Phase 7).
      homeFeedSourceProvider.overrideWithValue(const DemoHomeFeedSource()),
      // DEMO PLAYER (no sound) until the audio engine exists (Phase 6).
      playbackControllerProvider.overrideWithValue(DemoPlaybackController()),
      isDemoPlaybackProvider.overrideWithValue(true),
    ],
  );
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
