import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One sound in the embedded SoundCloud player, as its official Widget
/// API reports it. Shown for this session only, never stored.
@immutable
final class SoundCloudSound {
  const SoundCloudSound({
    required this.title,
    this.author,
    this.artwork,
    this.duration,
    this.url,
  });

  /// Null while the widget has not loaded this sound's details yet (long
  /// playlists load lazily).
  final String? title;
  final String? author;
  final Uri? artwork;
  final Duration? duration;

  /// The sound's page on SoundCloud (attribution link).
  final Uri? url;

  static SoundCloudSound? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    String? text(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    Uri? https(Object? v) {
      final uri = v is String ? Uri.tryParse(v) : null;
      return uri != null && uri.isScheme('https') ? uri : null;
    }

    final ms = json['durationMs'];
    return SoundCloudSound(
      title: text(json['title']),
      author: text(json['author']),
      artwork: https(json['artwork']),
      duration: ms is int && ms > 0 ? Duration(milliseconds: ms) : null,
      url: https(json['url']),
    );
  }
}

/// State and commands of SoundCloud's embedded player.
///
/// Playback happens only inside the official widget (a web view); AURA
/// shows its sound list and sends play/pause/skip through the official
/// Widget API. It is never mixed into AURA's own queue: SoundCloud's terms
/// forbid combining its sounds with other services' content.
///
/// The view wires [send] to the widget and feeds its messages to
/// [handleMessage]. Messages are untrusted text: anything malformed is
/// ignored.
class SoundCloudPlayerController extends ChangeNotifier {
  SoundCloudPlayerController({this.onStartedPlaying});

  /// Called when the widget starts playing, so AURA's own player pauses.
  final VoidCallback? onStartedPlaying;

  /// Delivers a command to the widget; set by the view once it is ready.
  void Function(Map<String, Object?> command)? send;

  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  int? _currentIndex;
  Duration _position = Duration.zero;
  List<SoundCloudSound> _sounds = const [];

  /// The widget has loaded and accepts commands.
  bool get isReady => _ready;

  /// The widget reported an error (page private, removed, or blocked).
  bool get hasFailed => _failed;
  bool get isPlaying => _playing;
  int? get currentIndex => _currentIndex;
  Duration get position => _position;
  List<SoundCloudSound> get sounds => _sounds;

  void play() => _command({'type': 'play'});

  void pause() => _command({'type': 'pause'});

  void toggle() => _playing ? pause() : play();

  void skipTo(int index) {
    if (index < 0 || index >= _sounds.length) return;
    _command({'type': 'skip', 'index': index});
  }

  void next() => _command({'type': 'next'});

  void previous() => _command({'type': 'prev'});

  void seek(Duration position) =>
      _command({'type': 'seek', 'positionMs': position.inMilliseconds});

  void _command(Map<String, Object?> command) {
    if (!_ready) return;
    send?.call({'target': 'aura-sc', ...command});
  }

  /// A message from the bridge page.
  void handleMessage(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, Object?> || decoded['source'] != 'aura-sc') {
      return;
    }
    switch (decoded['type']) {
      case 'ready':
        _ready = true;
        _failed = false;
      case 'sounds':
        final list = decoded['sounds'];
        if (list is List<Object?>) {
          _sounds = List.unmodifiable([
            for (final s in list.take(500)) ?SoundCloudSound.fromJson(s),
          ]);
        }
      case 'play':
        final wasPlaying = _playing;
        _playing = true;
        _index(decoded['index']);
        if (!wasPlaying) onStartedPlaying?.call();
      case 'pause' || 'finish':
        _playing = false;
      case 'progress':
        final ms = decoded['positionMs'];
        if (ms is int && ms >= 0) _position = Duration(milliseconds: ms);
        _index(decoded['index']);
      case 'error':
        _failed = true;
        _playing = false;
      default:
        return;
    }
    notifyListeners();
  }

  void _index(Object? value) {
    if (value is int && value >= 0) _currentIndex = value;
  }
}
