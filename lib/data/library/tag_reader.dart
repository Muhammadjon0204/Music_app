import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

final class CoverImage {
  const CoverImage(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// Tags read from an audio file. Everything is optional: files often have
/// partial or no tags.
final class TrackTags {
  const TrackTags({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.duration,
    this.cover,
  });

  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final Duration? duration;
  final CoverImage? cover;
}

abstract interface class TagReader {
  /// Never throws: unreadable tags yield empty [TrackTags], since the audio
  /// itself may still play.
  Future<TrackTags> read(String path);
}

/// Reads tags with the pure-Dart audio_metadata_reader package, off the UI
/// isolate (its parser is synchronous).
final class AudioMetadataTagReader implements TagReader {
  const AudioMetadataTagReader();

  /// Covers larger than this are ignored to bound memory use.
  static const maxCoverBytes = 5 * 1024 * 1024;

  @override
  Future<TrackTags> read(String path) async {
    try {
      return await Isolate.run(() => readSync(path));
    } on Object {
      return const TrackTags();
    }
  }

  static TrackTags readSync(String path) {
    try {
      final m = readMetadata(File(path), getImage: true);
      final pictures = [...m.pictures]
        ..sort(
          (a, b) => (a.pictureType == PictureType.coverFront ? 0 : 1).compareTo(
            b.pictureType == PictureType.coverFront ? 0 : 1,
          ),
        );
      final picture = pictures
          .where((p) => p.bytes.isNotEmpty && p.bytes.length <= maxCoverBytes)
          .firstOrNull;
      return TrackTags(
        title: clean(m.title),
        artist: clean(m.artist),
        albumArtist: clean(m.albumArtist),
        album: clean(m.album),
        trackNumber: _positive(m.trackNumber),
        discNumber: _positive(m.discNumber),
        year: m.year?.year,
        duration: m.duration == Duration.zero ? null : m.duration,
        cover: picture == null
            ? null
            : CoverImage(picture.bytes, picture.mimetype),
      );
    } on Object {
      return const TrackTags();
    }
  }

  /// Trims, drops NUL padding common in ID3 tags, and maps blank to null.
  static String? clean(String? value) {
    final cleaned = value?.replaceAll('\u0000', '').trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static int? _positive(int? value) =>
      value == null || value <= 0 ? null : value;
}
