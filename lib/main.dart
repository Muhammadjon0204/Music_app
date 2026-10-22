import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/app/app.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/library/artwork_providers.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/just_audio_engine.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/data/library/file_track_importer.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/io_missing_file_checker.dart';
import 'package:music_app/data/library/library_home_feed_source.dart';
import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/data/library/sembast_library_repository.dart';
import 'package:music_app/data/library/system_audio_file_picker.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:sembast/sembast_io.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Real audio where just_audio exists; elsewhere (Windows/Linux dev builds)
  // a silent engine that the UI labels as such.
  final hasAudio = JustAudioEngine.isSupported;
  final AudioEngine engine = hasAudio
      ? JustAudioEngine()
      : SimulatedAudioEngine();

  // The library lives in the app's support directory. On the web there are
  // no persistent files, so it is kept in memory and import is unavailable.
  final (library, paths, storageFailure) = await _openLibrary();

  // Composition root: binds implementations to application contracts.
  final container = ProviderContainer(
    overrides: [
      libraryRepositoryProvider.overrideWithValue(library),
      libraryStorageFailureProvider.overrideWithValue(storageFailure),
      demoTracksProvider.overrideWithValue(DemoCatalog.tones),
      // DEMO DATA on Home until the user's library has music.
      homeFeedSourceProvider.overrideWithValue(
        LibraryHomeFeedSource(
          repository: library,
          whenEmpty: const DemoHomeFeedSource(),
        ),
      ),
      if (paths != null) ...[
        audioFilePickerProvider.overrideWithValue(
          const SystemAudioFilePicker(),
        ),
        trackImporterProvider.overrideWithValue(
          FileTrackImporter(repository: library, paths: paths),
        ),
        clearPickedFilesProvider.overrideWithValue(
          SystemAudioFilePicker.clearTemporaryFiles,
        ),
        missingFileCheckerProvider.overrideWithValue(
          IoMissingFileChecker(paths),
        ),
        artworkPathResolverProvider.overrideWithValue(
          (uri) => paths.resolve(uri.toString()),
        ),
      ],
      playbackControllerProvider.overrideWithValue(
        EnginePlaybackController(
          engine: engine,
          resolver: (track) => resolveTrackAudio(
            track,
            resolveFile: paths?.resolve,
            fileExists: paths == null ? null : (p) => File(p).existsSync(),
          ),
        ),
      ),
      isSilentPlaybackProvider.overrideWithValue(!hasAudio),
    ],
  );
  final logger = container.read(appLoggerProvider);
  if (storageFailure != null) {
    logger.error(
      'Library storage unavailable, using a temporary library',
      error: storageFailure.cause,
      stackTrace: storageFailure.stackTrace,
    );
  }

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

Future<(LibraryRepository, LibraryPaths?, AppFailure?)> _openLibrary() async {
  if (kIsWeb) return (InMemoryLibraryRepository(), null, null);
  try {
    final paths = await LibraryPaths.forApp();
    await Directory(paths.root).create(recursive: true);
    final repository = await SembastLibraryRepository.open(
      factory: databaseFactoryIo,
      path: paths.databasePath,
      paths: paths,
    );
    return (repository, paths, null);
  } on Object catch (e, stackTrace) {
    return (
      InMemoryLibraryRepository(),
      null,
      StorageFailure(
        debugMessage: 'Cannot open library: $e',
        cause: e,
        stackTrace: stackTrace,
      ),
    );
  }
}
