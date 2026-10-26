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

/// A catalog with artist pages and radio, both scripted by the test.
class FakeArtistCatalog extends FakeCatalogProvider
    implements ArtistProvider, RadioProvider {
  FakeArtistCatalog({super.search, super.popular});

  /// What [artist] answers; a name and 1200 followers by default.
  Future<Result<OnlineArtist>> Function(ExternalArtistId id) artistAnswer =
      (id) async => Ok(
        OnlineArtist(
          providerId: const ProviderId('catalog'),
          id: id,
          name: 'Artist ${id.value}',
          followerCount: 1200,
          bio: 'Био артиста',
          pageUrl: Uri.parse('https://catalog.test/artist/${id.value}'),
        ),
      );

  /// What [artistTracks] answers.
  Future<Result<ProviderPage<Track>>> Function(ExternalArtistId id)
  tracksAnswer = (id) async => Ok(
    ProviderPage(
      items: [
        artistTrack('${id.value}-1', artist: id.value),
        artistTrack('${id.value}-2', artist: id.value),
      ],
    ),
  );

  /// What [radioFor] answers, given the seed.
  Future<Result<List<Track>>> Function(Track seed) radioAnswer = (seed) async =>
      Ok([for (var i = 0; i < 5; i++) onlineTrack('r$i-${seed.id.value}')]);

  final radioSeeds = <Track>[];

  @override
  Future<Result<OnlineArtist>> artist(
    ExternalArtistId id, {
    Cancellation? cancellation,
  }) => artistAnswer(id);

  @override
  Future<Result<ProviderPage<Track>>> artistTracks(
    ExternalArtistId id, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) => tracksAnswer(id);

  @override
  Future<Result<List<Track>>> radioFor(
    Track seed, {
    int limit = 30,
    Cancellation? cancellation,
  }) {
    radioSeeds.add(seed);
    return radioAnswer(seed);
  }
}

/// An online track of the default catalog by artist [artist] (its ID).
Track artistTrack(String id, {String artist = 'a1'}) {
  final source = ProviderTrackSource(
    providerId: const ProviderId('catalog'),
    externalId: ExternalTrackId(id),
    availability: StreamAvailability.full,
    originalUrl: Uri.parse('https://catalog.test/track/$id'),
    artistExternalId: ExternalArtistId(artist),
  );
  return Track(
    id: source.trackId,
    title: 'Track $id',
    artistName: 'Artist $artist',
    duration: const Duration(minutes: 3),
    sources: [source],
  );
}

/// Records shares instead of opening the system sheet.
class FakeLinkSharer implements LinkSharer {
  final shared = <(String, Uri?)>[];

  @override
  Future<bool> share({
    required String text,
    Uri? uri,
    ShareOrigin? origin,
  }) async {
    shared.add((text, uri));
    return true;
  }
}
