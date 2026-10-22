import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';

/// A file the user picked, as a temporary readable copy.
final class PickedAudioFile {
  const PickedAudioFile({required this.path, required this.name});

  /// Readable path; may be a temporary copy the OS deletes later.
  final String path;

  /// Original file name, for titles and error reports.
  final String name;
}

/// Opens the system file picker for audio files. Returns an empty list when
/// the user cancels.
abstract interface class AudioFilePicker {
  bool get isSupported;

  Future<List<PickedAudioFile>> pick();
}

enum ImportSkipReason { duplicate, unreadable, unsupported }

final class ImportReport {
  const ImportReport({this.imported = const [], this.skipped = const {}});

  final List<Track> imported;

  /// File name → why it was not imported.
  final Map<String, ImportSkipReason> skipped;

  int get duplicates =>
      skipped.values.where((r) => r == ImportSkipReason.duplicate).length;

  int get failed => skipped.length - duplicates;
}

/// Copies picked files into the library and reads their tags.
abstract interface class TrackImporter {
  Future<ImportReport> importFiles(
    List<PickedAudioFile> files, {
    void Function(int done, int total)? onProgress,
  });
}

/// Finds library tracks whose audio file has disappeared.
abstract interface class MissingFileChecker {
  Future<Set<TrackId>> findMissing(List<Track> tracks);
}
