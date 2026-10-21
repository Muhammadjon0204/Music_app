import 'package:music_app/domain/music/ids.dart';

final class Artist {
  const Artist({required this.id, required this.name, this.artworkUri});

  final ArtistId id;
  final String name;
  final Uri? artworkUri;

  @override
  bool operator ==(Object other) =>
      other is Artist &&
      other.id == id &&
      other.name == name &&
      other.artworkUri == artworkUri;

  @override
  int get hashCode => Object.hash(id, name, artworkUri);
}
