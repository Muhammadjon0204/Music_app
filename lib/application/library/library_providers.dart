import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';

/// Bound at the composition root and in tests.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => throw UnimplementedError(
    'libraryRepositoryProvider must be overridden at the composition root',
  ),
  retry: (_, _) => null,
);

/// Set when the on-device library could not be opened; the app then runs on
/// a temporary in-memory library and says so.
final libraryStorageFailureProvider = Provider<AppFailure?>((ref) => null);

final librarySnapshotProvider = StreamProvider<LibrarySnapshot>(
  (ref) => ref.watch(libraryRepositoryProvider).watch(),
  retry: (_, _) => null,
);

/// Null where files cannot be picked (tests, web).
final audioFilePickerProvider = Provider<AudioFilePicker?>((ref) => null);

final trackImporterProvider = Provider<TrackImporter?>((ref) => null);

/// Called after an import so the picker's temporary copies are removed.
final clearPickedFilesProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

final missingFileCheckerProvider = Provider<MissingFileChecker?>((ref) => null);

/// Library tracks whose audio file has disappeared since import.
final missingTracksProvider = FutureProvider<Set<TrackId>>((ref) async {
  final checker = ref.watch(missingFileCheckerProvider);
  final library = await ref.watch(librarySnapshotProvider.future);
  if (checker == null) return const {};
  return checker.findMissing(library.tracks);
}, retry: (_, _) => null);

/// Bundled sample tracks the user can add to try the app.
final demoTracksProvider = Provider<List<Track>>((ref) => const []);

/// How track lists are ordered (for this session).
final trackSortProvider = NotifierProvider<TrackSortController, TrackSort>(
  TrackSortController.new,
);

class TrackSortController extends Notifier<TrackSort> {
  @override
  TrackSort build() => TrackSort.title;

  void select(TrackSort sort) => state = sort;
}

sealed class ImportState {
  const ImportState();
}

final class ImportIdle extends ImportState {
  const ImportIdle();
}

final class ImportRunning extends ImportState {
  const ImportRunning({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ImportRunning && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

final class ImportFinished extends ImportState {
  const ImportFinished(this.report);

  final ImportReport report;
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);

class ImportController extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportIdle();

  bool get isSupported =>
      (ref.read(audioFilePickerProvider)?.isSupported ?? false) &&
      ref.read(trackImporterProvider) != null;

  /// Opens the picker and imports what the user selects. Ignored while an
  /// import is already running.
  Future<void> importFromDevice() async {
    final picker = ref.read(audioFilePickerProvider);
    final importer = ref.read(trackImporterProvider);
    if (state is ImportRunning || picker == null || importer == null) return;

    final files = await picker.pick();
    if (files.isEmpty) return;

    state = ImportRunning(done: 0, total: files.length);
    ImportReport report;
    try {
      report = await importer.importFiles(
        files,
        onProgress: (done, total) {
          state = ImportRunning(done: done, total: total);
        },
      );
    } on Object catch (e, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Import failed', error: e, stackTrace: stackTrace);
      report = ImportReport(
        skipped: {for (final f in files) f.name: ImportSkipReason.unreadable},
      );
    }
    await ref.read(clearPickedFilesProvider)();
    state = ImportFinished(report);
  }

  void dismiss() => state = const ImportIdle();

  /// Adds the bundled demo tracks to the library.
  Future<Result<void>> addDemoTracks() {
    final now = DateTime.now();
    return ref.read(libraryRepositoryProvider).addTracks([
      for (final track in ref.read(demoTracksProvider))
        Track(
          id: track.id,
          title: track.title,
          sources: track.sources,
          artistName: track.artistName,
          albumTitle: track.albumTitle,
          albumArtist: track.albumArtist,
          trackNumber: track.trackNumber,
          duration: track.duration,
          addedAt: now,
        ),
    ]);
  }
}
