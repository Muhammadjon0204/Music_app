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
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.duration,
    this.artworkUri,
    List<Uri> artworkAlternatives = const [],
    this.addedAt,
  }) : sources = List.unmodifiable(sources),
       artworkAlternatives = List.unmodifiable(artworkAlternatives) {
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

  /// Artist credited for the whole album (compilations, features).
  final String? albumArtist;
  final int? trackNumber;
  final int? discNumber;
  final int? year;

  /// Duration from metadata. The audio engine may report a different value.
  final Duration? duration;
  final Uri? artworkUri;

  /// The same cover on other hosts, tried in order when [artworkUri] fails
  /// (online providers replicate images across nodes). Not stored.
  final List<Uri> artworkAlternatives;

  /// When the track entered the library.
  final DateTime? addedAt;

  /// The artist a track is filed under: the album artist when present.
  String? get primaryArtist => albumArtist ?? artistName;

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
      other.albumArtist == albumArtist &&
      other.trackNumber == trackNumber &&
      other.discNumber == discNumber &&
      other.year == year &&
      other.duration == duration &&
      other.artworkUri == artworkUri &&
      elementsEqual(other.artworkAlternatives, artworkAlternatives) &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    Object.hashAll(sources),
    artistName,
    artistId,
    albumTitle,
    albumId,
    albumArtist,
    trackNumber,
    discNumber,
    year,
    duration,
    artworkUri,
    Object.hashAll(artworkAlternatives),
    addedAt,
  );
}
