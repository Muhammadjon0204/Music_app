import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/audio_error_classifier.dart';

/// Real playback through just_audio (iOS, Android, web, macOS).
final class JustAudioEngine implements AudioEngine {
  // just_audio's own interruption handling is off: it would pause the
  // player behind the controller's back, leaving the UI out of sync.
  // EnginePlaybackController handles interruptions instead.
  JustAudioEngine({AudioPlayer? player})
    : _player = player ?? AudioPlayer(handleInterruptions: false);

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
  /// so audio plays with the silent switch on and in the background).
  /// Returns the session for its interruption events.
  static Future<AudioSession> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    return session;
  }

  @override
  Stream<AudioEngineState> get states => _player.playerStateStream
      .map(
        (state) => AudioEngineState(
          phase: switch (state.processingState) {
            ProcessingState.idle => AudioEnginePhase.idle,
            ProcessingState.loading => AudioEnginePhase.loading,
            ProcessingState.buffering => AudioEnginePhase.buffering,
            ProcessingState.ready => AudioEnginePhase.ready,
            ProcessingState.completed => AudioEnginePhase.completed,
          },
          playing: state.playing,
        ),
      )
      .distinct();

  @override
  Stream<AudioEngineError> get errors => _player.errorStream.map(
    (e) => AudioEngineError(
      _classify(e.code, e.message),
      'code ${e.code}: ${e.message}',
    ),
  );

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
      // just_audio follows redirects (e.g. to a signed CDN URL) itself.
      StreamAudio(:final uri, :final headers) => AudioSource.uri(
        uri,
        headers: headers.isEmpty ? null : headers,
      ),
    };
    try {
      return await _player.setAudioSource(source);
    } on PlayerInterruptedException {
      throw const AudioLoadInterrupted();
    } on PlayerException catch (e) {
      throw AudioLoadException(
        'code ${e.code}: ${e.message}',
        kind: _classify(e.code, e.message),
      );
    } on PlatformException catch (e) {
      throw AudioLoadException('platform ${e.code}: ${e.message}');
    }
  }

  static AudioErrorKind _classify(int code, String? message) =>
      classifyAudioError(code: code, message: message, platform: _platform);

  static AudioPlatform get _platform {
    if (kIsWeb) return AudioPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => AudioPlatform.apple,
      TargetPlatform.android => AudioPlatform.android,
      _ => AudioPlatform.other,
    };
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
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
