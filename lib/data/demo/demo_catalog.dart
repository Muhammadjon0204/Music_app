import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// DEMO DATA — playable sample tracks bundled with the app.
///
/// The audio is synthesised by tool/generate_demo_tones.dart (no third-party
/// rights). Replaced by the user's own library in Phase 7.
abstract final class DemoCatalog {
  static const _artist = 'AURA · сгенерировано';
  static const _duration = Duration(seconds: 12);

  static final List<Track> tones = [
    for (final (i, title) in const [
      'Демо-тон · до мажор',
      'Демо-тон · ля минор',
      'Демо-тон · фа мажор',
      'Демо-тон · соль мажор',
    ].indexed)
      Track(
        id: TrackId('demo-tone-${i + 1}'),
        title: title,
        artistName: _artist,
        duration: _duration,
        sources: [BundledAudioSource('assets/demo_audio/tone_${i + 1}.wav')],
      ),
  ];
}
