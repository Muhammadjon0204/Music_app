import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/domain/library/library_search.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

Track track(String id, String title, {String? artist, String? album}) => Track(
  id: TrackId(id),
  title: title,
  artistName: artist,
  albumTitle: album,
  sources: [LocalFileSource('library:audio/$id.mp3')],
);

void main() {
  final library = LibrarySnapshot(
    tracks: [
      track('1', 'Ёлка', artist: 'Сплин', album: 'Гранатовый альбом'),
      track(
        '2',
        'Орбит без сахара',
        artist: 'Сплин',
        album: 'Гранатовый альбом',
      ),
      track('3', 'Звезда по имени Солнце', artist: 'Кино'),
      track('4', 'Без тегов'),
    ],
  );

  test('empty and blank queries find nothing', () {
    expect(searchLibrary(library, '').isEmpty, isTrue);
    expect(searchLibrary(library, '   ').isEmpty, isTrue);
  });

  test('ignores case, extra spaces and "ё"', () {
    final result = searchLibrary(library, '  ЕЛКА ');
    expect(result.tracks.map((t) => t.title), ['Ёлка']);
  });

  test('every word must match, across title, artist and album', () {
    expect(searchLibrary(library, 'сплин сахар').tracks.map((t) => t.title), [
      'Орбит без сахара',
    ]);
    expect(searchLibrary(library, 'кино сахар').isEmpty, isTrue);
  });

  test('finds albums and artists by name', () {
    final result = searchLibrary(library, 'гранат');
    expect(result.albums.map((a) => a.title), ['Гранатовый альбом']);
    expect(result.tracks, hasLength(2));
    expect(searchLibrary(library, 'спл').artists.map((a) => a.name), ['Сплин']);
  });

  test('results are capped', () {
    final big = LibrarySnapshot(
      tracks: [for (var i = 0; i < 200; i++) track('$i', 'Песня $i')],
    );
    expect(searchLibrary(big, 'песня').tracks, hasLength(50));
    expect(searchLibrary(big, 'песня', maxTracks: 5).tracks, hasLength(5));
  });

  test('regex-like characters are matched literally', () {
    final odd = LibrarySnapshot(tracks: [track('x', 'A.*B (live) [2020]')]);
    expect(searchLibrary(odd, '.*').tracks, hasLength(1));
    expect(searchLibrary(odd, '(live)').tracks, hasLength(1));
    expect(searchLibrary(odd, '[').tracks, hasLength(1));
  });
}
