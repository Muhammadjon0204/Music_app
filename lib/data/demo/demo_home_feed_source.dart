import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';

/// DEMO DATA — sample Home content for UI development only.
///
/// Album and playlist titles are fictional and not playable; the featured
/// playlist plays the generated demo tones. There is no artwork, and the
/// feed is flagged [HomeFeed.isDemo] so the UI labels it. To be replaced by
/// the user's real library in Phase 7.
final class DemoHomeFeedSource implements HomeFeedSource {
  const DemoHomeFeedSource();

  @override
  Future<Result<HomeFeed>> load() async {
    return Ok(
      HomeFeed(
        isDemo: true,
        featured: Playlist(
          id: const PlaylistId('demo-playlist-featured'),
          name: 'Демо-тоны',
          trackIds: [for (final track in DemoCatalog.tones) track.id],
        ),
        featuredTracks: DemoCatalog.tones,
        recentlyAdded: [
          _album('1', 'Ночные огни', 'Aurora Lines', 2024),
          _album('2', 'Неоновый дождь', 'Midnight Static', 2023),
          _album('3', 'Тихий океан', 'Lumen', 2022),
          _album('4', 'Северный ветер', 'Polar Sun', 2024),
        ],
        albums: [
          _album('5', 'Городские сны', 'Night Tram', 2021),
          _album('6', 'Вечерний вайб', 'Velvet Echo', 2024),
          _album('7', 'Бархатный шум', 'Soft Static', 2023),
          _album('8', 'Рассвет', 'Early Hours', 2020),
        ],
        playlists: [
          _playlist('evening', 'Вечерний вайб', 62),
          _playlist('focus', 'Для концентрации', 40),
          _playlist('road', 'В дорогу', 25),
          _playlist('one', 'Один трек', 1),
        ],
      ),
    );
  }

  static Album _album(String id, String title, String artist, int year) =>
      Album(
        id: AlbumId('demo-album-$id'),
        title: title,
        artistName: artist,
        year: year,
      );

  static Playlist _playlist(String id, String name, int trackCount) => Playlist(
    id: PlaylistId('demo-playlist-$id'),
    name: name,
    trackIds: [
      for (var i = 0; i < trackCount; i++) TrackId('demo-track-$id-$i'),
    ],
  );
}
