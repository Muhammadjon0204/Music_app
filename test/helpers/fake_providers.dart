import 'dart:async';

import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/external_links.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// A provider that only opens links: no capabilities.
class LinkOnlyProvider implements MusicProvider {
  const LinkOnlyProvider();

  @override
  ProviderId get id => const ProviderId('links');

  @override
  String get displayName => 'Links';
}

/// A streaming provider whose answers the test controls.
class FakeStreamingProvider implements StreamingProvider {
  FakeStreamingProvider(this.respond);

  /// Answers each streamUri call; may wait for the test.
  Future<Result<Uri>> Function(ExternalTrackId id) respond;
  final requested = <ExternalTrackId>[];
  final cancellations = <Cancellation?>[];

  @override
  ProviderId get id => const ProviderId('fake');

  @override
  String get displayName => 'Fake';

  @override
  Future<Result<Uri>> streamUri(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) {
    requested.add(id);
    cancellations.add(cancellation);
    return respond(id);
  }
}

/// A catalog provider (search, popular, streaming) the test scripts.
class FakeCatalogProvider
    implements SearchableProvider, PopularTracksProvider, StreamingProvider {
  FakeCatalogProvider({
    this.providerId = const ProviderId('catalog'),
    this.name = 'Каталог',
    Future<Result<ProviderPage<Track>>> Function(
      String query,
      PageRequest page,
    )?
    search,
    Future<Result<ProviderPage<Track>>> Function()? popular,
  }) : search = search ?? ((_, _) async => Ok(ProviderPage(items: const []))),
       popular = popular ?? (() async => Ok(ProviderPage(items: const [])));

  final ProviderId providerId;
  final String name;
  Future<Result<ProviderPage<Track>>> Function(String query, PageRequest page)
  search;
  Future<Result<ProviderPage<Track>>> Function() popular;
  final searches = <(String, int)>[];
  final searchCancellations = <Cancellation?>[];
  int popularCalls = 0;

  @override
  ProviderId get id => providerId;

  @override
  String get displayName => name;

  @override
  Future<Result<ProviderPage<Track>>> searchTracks(
    String query, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) {
    searches.add((query, page.offset));
    searchCancellations.add(cancellation);
    return search(query, page);
  }

  @override
  Future<Result<ProviderPage<Track>>> popularTracks({
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) {
    popularCalls++;
    return popular();
  }

  @override
  Future<Result<Uri>> streamUri(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) async => Ok(Uri.parse('https://stream.test/${id.value}'));
}

/// An online track of [provider] with the given availability.
Track onlineTrack(
  String id, {
  String provider = 'catalog',
  String? title,
  StreamAvailability availability = StreamAvailability.full,
}) {
  final source = ProviderTrackSource(
    providerId: ProviderId(provider),
    externalId: ExternalTrackId(id),
    availability: availability,
    originalUrl: Uri.parse('https://catalog.test/track/$id'),
  );
  return Track(
    id: source.trackId,
    title: title ?? 'Online $id',
    artistName: 'Artist $id',
    duration: const Duration(minutes: 3),
    sources: [source],
  );
}

/// Records opened links instead of leaving the app.
class FakeLinkOpener implements ExternalLinkOpener {
  final opened = <Uri>[];
  bool succeed = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeed;
  }
}
