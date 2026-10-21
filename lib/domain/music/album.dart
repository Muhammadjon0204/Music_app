import 'package:music_app/domain/music/ids.dart';

final class Album {
  const Album({
    required this.id,
    required this.title,
    this.artistName,
    this.artistId,
    this.year,
    this.artworkUri,
  });

  final AlbumId id;
  final String title;
  final String? artistName;
  final ArtistId? artistId;
  final int? year;
  final Uri? artworkUri;

  @override
  bool operator ==(Object other) =>
      other is Album &&
      other.id == id &&
      other.title == title &&
      other.artistName == artistName &&
      other.artistId == artistId &&
      other.year == year &&
      other.artworkUri == artworkUri;

  @override
  int get hashCode =>
      Object.hash(id, title, artistName, artistId, year, artworkUri);
}
