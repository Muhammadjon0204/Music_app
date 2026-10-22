import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/data/library/tag_reader.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:path/path.dart' as p;

/// Imports picked files into the library.
///
/// Files are copied into the app's own storage: picker results are
/// temporary copies the OS may delete, so keeping a reference to them would
/// break after a restart. Copies are named by content hash, which also
/// detects duplicates.
final class FileTrackImporter implements TrackImporter {
  FileTrackImporter({
    required this._repository,
    required this._paths,
    this._tags = const AudioMetadataTagReader(),
    this._now = DateTime.now,
  });

  /// Formats iOS plays natively. Others (e.g. OGG) are reported, not copied.
  static const supportedExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.aac',
    '.wav',
    '.aif',
    '.aiff',
    '.aifc',
    '.caf',
    '.flac',
  };

  final LibraryRepository _repository;
  final LibraryPaths _paths;
  final TagReader _tags;
  final DateTime Function() _now;

  @override
  Future<ImportReport> importFiles(
    List<PickedAudioFile> files, {
    void Function(int done, int total)? onProgress,
  }) async {
    final imported = <Track>[];
    final skipped = <String, ImportSkipReason>{};
    final known = {for (final t in _repository.current.tracks) t.id};

    await Directory(_paths.audioDir).create(recursive: true);
    await Directory(_paths.artworkDir).create(recursive: true);

    for (final (index, file) in files.indexed) {
      switch (await _importOne(file, known)) {
        case _Imported(:final track):
          imported.add(track);
          known.add(track.id);
        case _Skipped(:final reason):
          skipped[file.name] = reason;
      }
      onProgress?.call(index + 1, files.length);
    }

    if (imported.isNotEmpty) {
      final saved = await _repository.addTracks(imported);
      if (saved is Err) {
        return ImportReport(
          skipped: {
            ...skipped,
            for (final file in files)
              if (!skipped.containsKey(file.name))
                file.name: ImportSkipReason.unreadable,
          },
        );
      }
    }
    return ImportReport(imported: imported, skipped: skipped);
  }

  Future<_Outcome> _importOne(PickedAudioFile file, Set<TrackId> known) async {
    final extension = p.extension(file.name).toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      return const _Skipped(ImportSkipReason.unsupported);
    }
    try {
      final source = File(file.path);
      final hash = (await sha256.bind(source.openRead()).first).toString();
      final id = TrackId('local-${hash.substring(0, 32)}');
      if (known.contains(id)) return const _Skipped(ImportSkipReason.duplicate);

      final fileName = '${hash.substring(0, 32)}$extension';
      final copy = File(p.join(_paths.audioDir, fileName));
      if (!await copy.exists()) await source.copy(copy.path);

      final tags = await _tags.read(copy.path);
      final fallbackTitle = p.basenameWithoutExtension(file.name).trim();
      return _Imported(
        Track(
          id: id,
          title:
              tags.title ?? (fallbackTitle.isEmpty ? file.name : fallbackTitle),
          sources: [LocalFileSource(LibraryPaths.reference('audio/$fileName'))],
          artistName: tags.artist,
          albumTitle: tags.album,
          albumArtist: tags.albumArtist,
          trackNumber: tags.trackNumber,
          discNumber: tags.discNumber,
          year: tags.year,
          duration: tags.duration,
          artworkUri: await _saveCover(tags.cover),
          addedAt: _now(),
        ),
      );
    } on FileSystemException {
      return const _Skipped(ImportSkipReason.unreadable);
    }
  }

  /// Stores a cover once per distinct image, shared by an album's tracks.
  Future<Uri?> _saveCover(CoverImage? cover) async {
    if (cover == null) return null;
    final extension = switch (cover.mimeType.toLowerCase()) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
    final name =
        '${sha256.convert(cover.bytes).toString().substring(0, 32)}'
        '$extension';
    final file = File(p.join(_paths.artworkDir, name));
    try {
      if (!await file.exists()) await file.writeAsBytes(cover.bytes);
      return Uri.parse(LibraryPaths.reference('artwork/$name'));
    } on FileSystemException {
      return null;
    }
  }
}

sealed class _Outcome {
  const _Outcome();
}

final class _Imported extends _Outcome {
  const _Imported(this.track);

  final Track track;
}

final class _Skipped extends _Outcome {
  const _Skipped(this.reason);

  final ImportSkipReason reason;
}
