import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/demo/demo_catalog.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

const online = ProviderTrackSource(
  providerId: ProviderId('p'),
  externalId: ExternalTrackId('1'),
);

Track withSources(List<TrackSource> sources) =>
    Track(id: const TrackId('t'), title: 'T', sources: sources);

void main() {
  group('resolveTrackAudio', () {
    test('bundled audio becomes an asset', () {
      final result = resolveTrackAudio(
        withSources(const [BundledAudioSource('assets/a.wav')]),
      );
      expect((result as Ok<AudioLocation>).value, isA<AssetAudio>());
    });

    test('a local file becomes a file location', () {
      final result = resolveTrackAudio(
        withSources(const [LocalFileSource('/music/a.m4a')]),
      );
      expect((result as Ok<AudioLocation>).value, isA<FileAudio>());
    });

    test('online sources are skipped until providers exist', () {
      final result = resolveTrackAudio(
        withSources(const [online, LocalFileSource('/music/a.m4a')]),
      );
      expect((result as Ok<AudioLocation>).value, isA<FileAudio>());
    });

    test('online-only tracks are reported as unplayable', () {
      final result = resolveTrackAudio(withSources(const [online]));
      expect((result as Err).failure, isA<UnsupportedMediaFailure>());
    });

    test('file paths never appear in log output', () {
      expect(
        '${const FileAudio('/private/user/song.m4a')}',
        isNot(contains('/')),
      );
    });
  });

  group('SimulatedAudioEngine', () {
    testWidgets('needs a duration to load', (tester) async {
      final engine = SimulatedAudioEngine();
      expect(
        () => engine.load(const AssetAudio('x')),
        throwsA(isA<AudioLoadException>()),
      );
      await engine.dispose();
    });

    testWidgets('completes and keeps "playing" like just_audio', (
      tester,
    ) async {
      final engine = SimulatedAudioEngine(
        tick: const Duration(milliseconds: 100),
      );
      final states = <AudioEngineState>[];
      engine.states.listen(states.add);

      await engine.load(
        const AssetAudio('x'),
        expectedDuration: const Duration(seconds: 1),
      );
      await engine.play();
      await tester.pump(const Duration(seconds: 2));

      expect(
        states.last,
        const AudioEngineState(
          phase: AudioEnginePhase.completed,
          playing: true,
        ),
      );
      expect(engine.position, const Duration(seconds: 1));

      // Seeking back after completion resumes playback.
      await engine.seek(Duration.zero);
      await tester.pump(const Duration(milliseconds: 300));
      expect(engine.position, const Duration(milliseconds: 300));
      await engine.dispose();
    });

    testWidgets('dispose stops the timer', (tester) async {
      final engine = SimulatedAudioEngine();
      await engine.load(
        const AssetAudio('x'),
        expectedDuration: const Duration(seconds: 5),
      );
      await engine.play();
      await engine.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(engine.position, Duration.zero);
    });
  });

  group('demo tones', () {
    // Parses the WAV header and checks the audio matches the metadata.
    for (final track in DemoCatalog.tones) {
      test('${track.title}: asset exists and lasts ${track.duration}', () {
        final source = track.sources.single as BundledAudioSource;
        final bytes = File(source.assetPath).readAsBytesSync();
        final header = ByteData.sublistView(bytes, 0, 44);

        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
        final sampleRate = header.getUint32(24, Endian.little);
        final bytesPerSecond = header.getUint32(28, Endian.little);
        final dataBytes = header.getUint32(40, Endian.little);

        expect(sampleRate, greaterThan(0));
        expect(
          Duration(milliseconds: dataBytes * 1000 ~/ bytesPerSecond),
          track.duration,
        );
      });
    }

    test('the asset folder is declared in pubspec.yaml', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/demo_audio/'),
      );
    });
  });
}
