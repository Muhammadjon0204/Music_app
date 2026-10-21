import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/ids.dart';

/// A user playlist. Refers to library tracks by [TrackId], so local and
/// online tracks can be mixed in one playlist.
final class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required List<TrackId> trackIds,
    this.artworkUri,
  }) : trackIds = List.unmodifiable(trackIds);

  final PlaylistId id;
  final String name;
  final List<TrackId> trackIds;
  final Uri? artworkUri;

  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.name == name &&
      elementsEqual(other.trackIds, trackIds) &&
      other.artworkUri == artworkUri;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(trackIds), artworkUri);
}
