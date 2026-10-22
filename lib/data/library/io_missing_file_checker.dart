import 'dart:io';

import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// Finds library tracks whose copied audio file no longer exists.
final class IoMissingFileChecker implements MissingFileChecker {
  const IoMissingFileChecker(this._paths);

  final LibraryPaths _paths;

  @override
  Future<Set<TrackId>> findMissing(List<Track> tracks) async {
    final missing = <TrackId>{};
    for (final track in tracks) {
      for (final source in track.sources) {
        if (source is! LocalFileSource) continue;
        final path =
            _paths.resolve(source.fileReference) ?? source.fileReference;
        if (!await File(path).exists()) missing.add(track.id);
      }
    }
    return missing;
  }
}
