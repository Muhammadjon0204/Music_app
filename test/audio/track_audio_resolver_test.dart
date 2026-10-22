import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';

Track _track(List<TrackSource> sources) =>
    Track(id: const TrackId('t'), title: 'T', sources: sources);

ProviderTrackSource _online({
  StreamAvailability availability = StreamAvailability.full,
  String provider = 'fake',
}) => ProviderTrackSource(
  providerId: ProviderId(provider),
  externalId: const ExternalTrackId('42'),
  availability: availability,
);

final _streamUrl = Uri.parse('https://api.example.test/v1/tracks/42/stream');

void main() {
  late FakeStreamingProvider provider;
  late TrackAudioResolver resolve;

  setUp(() {
    provider = FakeStreamingProvider((_) async => Ok(_streamUrl));
    resolve = TrackAudioResolver(providers: ProviderRegistry([provider]));
  });

  Future<Result<AudioLocation>> run(List<TrackSource> sources) =>
      resolve(_track(sources), Cancellation());

  test('a bundled asset resolves without the network', () async {
    final result = await run(const [BundledAudioSource('assets/a.wav')]);
    expect((result as Ok).value, isA<AssetAudio>());
    expect(provider.requested, isEmpty);
  });

  test('a local file resolves to its path', () async {
    final result = await run(const [LocalFileSource('/music/a.m4a')]);
    expect(((result as Ok).value as FileAudio).path, '/music/a.m4a');
  });

  test('a missing local file is a file failure', () async {
    final resolver = TrackAudioResolver(fileExists: (_) => false);
    final result = await resolver(
      _track(const [LocalFileSource('/music/gone.m4a')]),
      Cancellation(),
    );
    expect((result as Err).failure, isA<FileAccessFailure>());
  });

  test('a streamable online track resolves to an HTTPS stream', () async {
    final result = await run([_online()]);
    final location = (result as Ok).value as StreamAudio;
    expect(location.uri, _streamUrl);
    expect(provider.requested, [const ExternalTrackId('42')]);
  });

  test('an unknown availability still asks the provider', () async {
    final result = await run([
      _online(availability: StreamAvailability.unknown),
    ]);
    expect(result, isA<Ok<AudioLocation>>());
  });

  test('a link-only track says so without asking the network', () async {
    final result = await run([
      _online(availability: StreamAvailability.externalOnly),
    ]);
    expect((result as Err).failure, isA<FeatureUnavailableFailure>());
    expect(provider.requested, isEmpty);
  });

  test('an unavailable track is reported as such', () async {
    final result = await run([
      _online(availability: StreamAvailability.unavailable),
    ]);
    expect((result as Err).failure, isA<AccessDeniedFailure>());
  });

  test('a provider that is not registered is a clear failure', () async {
    final result = await run([_online(provider: 'unknown')]);
    expect((result as Err).failure, isA<FeatureUnavailableFailure>());
  });

  test('a provider without streaming cannot be played', () async {
    final resolver = TrackAudioResolver(
      providers: ProviderRegistry([const LinkOnlyProvider()]),
    );
    final result = await resolver(
      _track([_online(provider: 'links')]),
      Cancellation(),
    );
    expect((result as Err).failure, isA<FeatureUnavailableFailure>());
  });

  test('provider errors are passed on unchanged', () async {
    provider.respond = (_) async => const Err(NotFoundFailure());
    final result = await run([_online()]);
    expect((result as Err).failure, isA<NotFoundFailure>());
  });

  test('a non-HTTPS stream URL is refused', () async {
    provider.respond = (_) async => Ok(Uri.parse('http://insecure.test/a'));
    final result = await run([_online()]);
    expect((result as Err).failure, isA<InvalidResponseFailure>());
  });

  test('falls back to the next source when one fails', () async {
    provider.respond = (_) async => const Err(ServerFailure());
    final result = await run([
      _online(),
      const LocalFileSource('/music/copy.mp3'),
    ]);
    expect((result as Ok).value, isA<FileAudio>());
  });

  test('when every source fails, the first failure explains why', () async {
    provider.respond = (_) async => const Err(RateLimitedFailure());
    final result = await run([
      _online(),
      _online(availability: StreamAvailability.unavailable),
    ]);
    expect((result as Err).failure, isA<RateLimitedFailure>());
  });

  test('cancellation reaches the provider and wins over its answer', () async {
    final answer = Completer<Result<Uri>>();
    provider.respond = (_) => answer.future;
    final cancellation = Cancellation();
    final pending = resolve(_track([_online()]), cancellation);
    await Future<void>.delayed(Duration.zero);
    expect(provider.cancellations.single, same(cancellation));

    cancellation.cancel();
    answer.complete(Ok(_streamUrl));
    expect((await pending as Err).failure, isA<CancelledFailure>());
  });

  test('stream locations never print their path or query', () {
    final location = StreamAudio(
      Uri.parse('https://cdn.test/tracks/abc?signature=SECRET'),
    );
    expect('$location', isNot(contains('SECRET')));
    expect('$location', isNot(contains('/tracks')));
  });

  test('stream locations must be HTTPS', () {
    expect(
      () => StreamAudio(Uri.parse('http://cdn.test/a.mp3')),
      throwsArgumentError,
    );
  });
}
