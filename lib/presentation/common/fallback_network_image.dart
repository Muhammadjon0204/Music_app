import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// A network image that tries [urls] in order until one loads: providers
/// such as Audius replicate covers across nodes, and any single node may
/// be down. Cached only in Flutter's in-memory image cache (the Audius API
/// terms allow session caching only), never on disk.
@immutable
final class FallbackNetworkImage extends ImageProvider<FallbackNetworkImage> {
  FallbackNetworkImage(List<Uri> urls, {this._client})
    : assert(urls.isNotEmpty),
      urls = List.unmodifiable(urls);

  final List<Uri> urls;
  final http.Client? _client;

  /// Per host; the next host is tried after this.
  static const timeout = Duration(seconds: 8);

  @override
  Future<FallbackNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    FallbackNetworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: 'FallbackNetworkImage(${urls.first.host})',
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final client = _client ?? http.Client();
    try {
      Object? lastError;
      for (final url in urls) {
        try {
          final response = await client.get(url).timeout(timeout);
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            lastError = 'HTTP ${response.statusCode} from ${url.host}';
            continue;
          }
          final buffer = await ui.ImmutableBuffer.fromUint8List(
            response.bodyBytes,
          );
          return await decode(buffer);
        } on Object catch (e) {
          // Unreachable host, timeout, or bytes that are not an image.
          lastError = e;
        }
      }
      // Evict, so a later visit tries again instead of caching a failure.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      throw StateError('No cover host answered: $lastError');
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FallbackNetworkImage && listEquals(other.urls, urls);

  @override
  int get hashCode => Object.hashAll(urls);

  @override
  String toString() => 'FallbackNetworkImage(${urls.length} hosts)';
}
