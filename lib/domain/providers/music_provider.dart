import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';

/// An online music source (Audius, SoundCloud links, ...).
///
/// Providers differ a lot, so the contract is split: every provider has an
/// identity, and implements only the capability interfaces it really
/// supports ([SearchableProvider], [PopularTracksProvider],
/// [TrackDetailsProvider], [StreamingProvider]). Callers go through
/// [ProviderRegistry], which reports a missing capability as
/// [FeatureUnavailableFailure] instead of throwing.
///
/// Tracks returned by providers carry a ProviderTrackSource whose
/// availability says whether AURA can stream them; metadata alone never
/// implies a playable stream.
abstract interface class MusicProvider {
  /// Short stable identifier without ":" (it prefixes track IDs).
  ProviderId get id;

  /// Name shown in attribution, e.g. "Audius".
  String get displayName;
}

/// One page of results and how to ask for the next.
final class ProviderPage<T> {
  ProviderPage({required List<T> items, this.nextOffset})
    : items = List.unmodifiable(items);

  final List<T> items;

  /// Offset of the next page, or null when this is the last one.
  final int? nextOffset;

  bool get hasMore => nextOffset != null;
}

final class PageRequest {
  const PageRequest({this.offset = 0, this.limit = 20})
    : assert(offset >= 0),
      assert(limit > 0);

  final int offset;
  final int limit;
}

abstract interface class SearchableProvider implements MusicProvider {
  Future<Result<ProviderPage<Track>>> searchTracks(
    String query, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  });
}

abstract interface class PopularTracksProvider implements MusicProvider {
  Future<Result<ProviderPage<Track>>> popularTracks({
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  });
}

abstract interface class TrackDetailsProvider implements MusicProvider {
  Future<Result<Track>> trackDetails(
    ExternalTrackId id, {
    Cancellation? cancellation,
  });
}

/// Providers whose tracks AURA's own player may stream.
abstract interface class StreamingProvider implements MusicProvider {
  /// A URL the audio engine can open now. It may redirect to a temporary
  /// signed URL, so it is resolved right before playback and never stored.
  Future<Result<Uri>> streamUri(
    ExternalTrackId id, {
    Cancellation? cancellation,
  });
}

/// The providers this build knows about. Local music needs none.
final class ProviderRegistry {
  ProviderRegistry([Iterable<MusicProvider> providers = const []])
    : _providers = {for (final p in providers) p.id: p} {
    for (final id in _providers.keys) {
      if (id.value.isEmpty || id.value.contains(':')) {
        throw ArgumentError.value(
          id.value,
          'provider id',
          'must not contain ":"',
        );
      }
    }
  }

  static final ProviderRegistry empty = ProviderRegistry();

  final Map<ProviderId, MusicProvider> _providers;

  Iterable<MusicProvider> get all => _providers.values;

  MusicProvider? operator [](ProviderId id) => _providers[id];

  /// The provider [id] if it supports capability [T], else a failure saying
  /// why not (unknown provider, or feature not offered).
  Result<T> capability<T extends MusicProvider>(ProviderId id) {
    final provider = _providers[id];
    if (provider == null) {
      return Err(
        FeatureUnavailableFailure(
          debugMessage: 'No provider registered as ${id.value}',
        ),
      );
    }
    if (provider is T) return Ok(provider);
    return Err(
      FeatureUnavailableFailure(
        debugMessage: '${id.value} does not support $T',
      ),
    );
  }
}
