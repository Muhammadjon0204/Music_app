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
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/audio_interruptions.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/just_audio_engine.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/audio/system_media_session.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/config/app_config.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/data/library/file_track_importer.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/platform/url_launcher_link_opener.dart';
import 'package:music_app/data/providers/audius/audius_provider.dart';
import 'package:music_app/data/providers/jamendo/jamendo_provider.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/in_memory_listening_store.dart';
import 'package:music_app/data/library/io_missing_file_checker.dart';
import 'package:music_app/data/library/library_home_feed_source.dart';
import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/data/library/sembast_library_repository.dart';
import 'package:music_app/data/library/sembast_listening_store.dart';
import 'package:music_app/data/library/system_audio_file_picker.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link_store.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_oembed.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_providers.dart';
import 'package:music_app/domain/providers/music_provider.dart';
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
  final (library, listening, paths, storageFailure) = await _openLibrary();

  // One logger for startup and the app (same settings as appLoggerProvider).
  final AppLogger logger = DeveloperLogger(
    enabled: AppConfig.fromEnvironment(isReleaseBuild: kReleaseMode)
        .loggingEnabled,
  );
  final session = hasAudio ? await _configureAudioSession(logger) : null;

  // Online catalogs: public read APIs, no secrets in the app. Jamendo only
  // when the build was given its client ID.
  final http = JsonHttpClient(logger: logger);
  final providers = ProviderRegistry([
    AudiusProvider(http: http),
    if (AppConfig.jamendoClientId.isNotEmpty)
      JamendoProvider(http: http, clientId: AppConfig.jamendoClientId),
  ]);
  // SoundCloud: saved links play in its official embedded player.
  final SoundCloudLinkStore soundCloudLinks =
      library is SembastLibraryRepository
      ? SembastSoundCloudLinkStore(library.database)
      : InMemorySoundCloudLinkStore();
  final playback = EnginePlaybackController(
    engine: engine,
    resolver: TrackAudioResolver(
      resolveFile: paths?.resolve,
      fileExists: paths == null ? null : (p) => File(p).existsSync(),
      providers: providers,
    ).call,
    interruptions: session == null ? null : audioSessionInterruptions(session),
  );
  // Lock screen, Control Center and headphone buttons.
  if (hasAudio && SystemMediaSession.isSupported) {
    await _startSystemMediaSession(
      () => SystemMediaSession(
        playback,
        artworkPath: paths == null ? null : (uri) => paths.resolve('$uri'),
      ),
      logger,
    );
  }

  // Composition root: binds implementations to application contracts.
  final container = ProviderContainer(
    overrides: [
      libraryRepositoryProvider.overrideWithValue(library),
      libraryStorageFailureProvider.overrideWithValue(storageFailure),
      listeningStoreProvider.overrideWithValue(listening),
      // Bundled demo tones the user can add to the library on request.
      demoTracksProvider.overrideWithValue(DemoCatalog.tones),
      // Home shows the library, and the real Audius catalog next to it;
      // the sample (demo) feed is no longer needed.
      homeFeedSourceProvider.overrideWithValue(
        LibraryHomeFeedSource(repository: library),
      ),
      providerRegistryProvider.overrideWithValue(providers),
      soundCloudLinkStoreProvider.overrideWithValue(soundCloudLinks),
      soundCloudOEmbedProvider.overrideWithValue(SoundCloudOEmbed(http)),
      externalLinkOpenerProvider.overrideWithValue(
        const UrlLauncherLinkOpener(),
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
      appLoggerProvider.overrideWithValue(logger),
      playbackControllerProvider.overrideWithValue(playback),
      isSilentPlaybackProvider.overrideWithValue(!hasAudio),
    ],
  );
  if (storageFailure != null) {
    logger.error(
      'Library storage unavailable, using a temporary library',
      error: storageFailure.cause,
      stackTrace: storageFailure.stackTrace,
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

  // Restores the last session in the background (online tracks may need
  // the network), then records listening history.
  container.listen(listeningSessionProvider, (_, _) {});

  runApp(
    UncontrolledProviderScope(container: container, child: const AuraApp()),
  );
}

/// The audio session for interruption events, or null when it cannot be
/// configured (playback still works, interruptions are not handled).
Future<AudioSession?> _configureAudioSession(AppLogger logger) async {
  try {
    return await JustAudioEngine.configureSession();
  } on Object catch (e, stackTrace) {
    logger.warning(
      'Audio session configuration failed',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Without system controls the app still plays while it is open, so a
/// failure is logged rather than shown.
Future<void> _startSystemMediaSession(
  SystemMediaSession Function() builder,
  AppLogger logger,
) async {
  try {
    await AudioService.init(
      builder: builder,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.aura.music.playback',
        androidNotificationChannelName: 'MusicLab',
      ),
    );
  } on Object catch (e, stackTrace) {
    logger.warning(
      'System media controls unavailable',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// The library and the listening history share one database file; on the
/// web (or when it cannot be opened) both live in memory.
Future<(LibraryRepository, ListeningStore, LibraryPaths?, AppFailure?)>
_openLibrary() async {
  if (kIsWeb) {
    return (InMemoryLibraryRepository(), InMemoryListeningStore(), null, null);
  }
  try {
    final paths = await LibraryPaths.forApp();
    await Directory(paths.root).create(recursive: true);
    final repository = await SembastLibraryRepository.open(
      factory: databaseFactoryIo,
      path: paths.databasePath,
      paths: paths,
    );
    return (
      repository,
      SembastListeningStore(repository.database),
      paths,
      null,
    );
  } on Object catch (e, stackTrace) {
    return (
      InMemoryLibraryRepository(),
      InMemoryListeningStore(),
      null,
      StorageFailure(
        debugMessage: 'Cannot open library: $e',
        cause: e,
        stackTrace: stackTrace,
      ),
    );
  }
}
