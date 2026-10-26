import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// Radio candidates from several lists (e.g. same genre, same artist), one
/// from each in turn: each track once, never [seed], never one known not to
/// play here, at most [limit].
List<Track> mixForRadio(
  List<List<Track>> lists, {
  required Track seed,
  required int limit,
  Set<TrackId> exclude = const {},
}) {
  final seen = {seed.id, ...exclude};
  final mixed = <Track>[];
  final longest = lists.fold(0, (n, l) => l.length > n ? l.length : n);
  for (var i = 0; i < longest && mixed.length < limit; i++) {
    for (final list in lists) {
      if (i >= list.length || mixed.length >= limit) continue;
      final track = list[i];
      if (!_playable(track) || !seen.add(track.id)) continue;
      mixed.add(track);
    }
  }
  return mixed;
}

bool _playable(Track track) => track.sources.any(
  (s) => switch (s) {
    ProviderTrackSource(:final availability) =>
      availability.canStreamInApp || availability == StreamAvailability.unknown,
    _ => true,
  },
);
