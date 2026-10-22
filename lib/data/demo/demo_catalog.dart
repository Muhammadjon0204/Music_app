import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// DEMO DATA — fictional tracks for UI development. There is no audio
/// behind them; the `demo:` references are never opened.
abstract final class DemoCatalog {
  static final List<Track> hits = [
    for (final (i, (title, artist, seconds)) in const [
      ('Северное сияние', 'Aurora Lines', 221),
      ('Неоновый дождь', 'Midnight Static', 198),
      ('Тихий океан', 'Lumen', 245),
      ('Полночный трамвай', 'Night Tram', 177),
      ('Бархатный шум', 'Soft Static', 213),
      ('Огни города', 'Velvet Echo', 192),
      ('Рассвет', 'Early Hours', 261),
      ('Звёздная пыль', 'Polar Sun', 229),
      ('Ветер перемен', null, 182),
      ('Последний поезд', 'Night Tram', 207),
      ('Глубина', 'Lumen', 310),
      ('Сон наяву', 'Aurora Lines', 238),
    ].indexed)
      Track(
        id: TrackId('demo-track-$i'),
        title: title,
        artistName: artist,
        duration: Duration(seconds: seconds),
        sources: [LocalFileSource('demo:hits/$i')],
      ),
  ];
}
