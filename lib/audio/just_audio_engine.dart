import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/audio/audio_engine.dart';

/// Real playback through just_audio (iOS, Android, web, macOS).
final class JustAudioEngine implements AudioEngine {
  JustAudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Platforms where just_audio has an implementation. Elsewhere (Windows,
  /// Linux) the app falls back to the silent engine.
  static bool get isSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.android ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  /// Declares the app as a music player to the OS (iOS: playback category,
  /// so audio plays with the silent switch on). Interruption handling comes
  /// with background audio in Phase 8.
  static Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  Stream<AudioEngineState> get states => _player.playerStateStream
      .map(
        (state) => AudioEngineState(
          phase: switch (state.processingState) {
            ProcessingState.idle => AudioEnginePhase.idle,
            ProcessingState.loading ||
            ProcessingState.buffering => AudioEnginePhase.loading,
            ProcessingState.ready => AudioEnginePhase.ready,
            ProcessingState.completed => AudioEnginePhase.completed,
          },
          playing: state.playing,
        ),
      )
      .distinct();

  @override
  Stream<Duration> get positions => _player.positionStream;

  @override
  Duration get position => _player.position;

  @override
  Future<Duration?> load(
    AudioLocation location, {
    Duration? expectedDuration,
  }) async {
    final source = switch (location) {
      AssetAudio(:final path) => AudioSource.asset(path),
      FileAudio(:final path) => AudioSource.file(path),
    };
    try {
      return await _player.setAudioSource(source);
    } on PlayerInterruptedException {
      throw const AudioLoadInterrupted();
    } on PlayerException catch (e) {
      throw AudioLoadException('code ${e.code}: ${e.message}');
    } on PlatformException catch (e) {
      throw AudioLoadException('platform ${e.code}: ${e.message}');
    }
  }

  // The plugin's play() future completes only when playback stops, so it
  // must not be awaited by commands.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
