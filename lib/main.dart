import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/just_audio_engine.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Real audio where just_audio exists; elsewhere (Windows/Linux dev builds)
  // a silent engine that the UI labels as such.
  final hasAudio = JustAudioEngine.isSupported;
  final AudioEngine engine = hasAudio
      ? JustAudioEngine()
      : SimulatedAudioEngine();

  // Composition root: binds implementations to application contracts.
  final container = ProviderContainer(
    overrides: [
      // DEMO DATA until the local library exists (Phase 7).
      homeFeedSourceProvider.overrideWithValue(const DemoHomeFeedSource()),
      playbackControllerProvider.overrideWithValue(
        EnginePlaybackController(engine: engine),
      ),
      isSilentPlaybackProvider.overrideWithValue(!hasAudio),
    ],
  );
  final logger = container.read(appLoggerProvider);

  if (hasAudio) {
    unawaited(
      JustAudioEngine.configureSession().catchError(
        (Object error, StackTrace stackTrace) => logger.warning(
          'Audio session configuration failed',
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }

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
