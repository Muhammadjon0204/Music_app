import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track_source.dart';

/// A recording in the user's library, independent of where it plays from.
///
/// Missing metadata is `null`, not a placeholder string such as "Unknown";
/// the presentation layer decides how to display it.
final class Track {
  Track({
    required this.id,
    required this.title,
    required List<TrackSource> sources,
    this.artistName,
    this.artistId,
    this.albumTitle,
    this.albumId,
    this.duration,
    this.artworkUri,
  }) : sources = List.unmodifiable(sources) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (this.sources.isEmpty) {
      throw ArgumentError.value(sources, 'sources', 'must not be empty');
    }
  }

  final TrackId id;

  /// Falls back to the file name when the file has no title tag.
  final String title;
  final List<TrackSource> sources;
  final String? artistName;
  final ArtistId? artistId;
  final String? albumTitle;
  final AlbumId? albumId;

  /// Duration from metadata. The audio engine may report a different value.
  final Duration? duration;
  final Uri? artworkUri;

  @override
  bool operator ==(Object other) =>
      other is Track &&
      other.id == id &&
      other.title == title &&
      elementsEqual(other.sources, sources) &&
      other.artistName == artistName &&
      other.artistId == artistId &&
      other.albumTitle == albumTitle &&
      other.albumId == albumId &&
      other.duration == duration &&
      other.artworkUri == artworkUri;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    Object.hashAll(sources),
    artistName,
    artistId,
    albumTitle,
    albumId,
    duration,
    artworkUri,
  );
}
