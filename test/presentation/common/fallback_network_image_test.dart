import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/presentation/common/fallback_network_image.dart';

import '../../helpers/audio_fixtures.dart';

final _primary = Uri.parse('https://down.example/content/abc/480x480.jpg');
final _mirror = Uri.parse('https://up.example/content/abc/480x480.jpg');

/// Resolves [image] and waits for the first frame or the error.
Future<Object?> _load(ImageProvider<Object> image) {
  final done = Completer<Object?>();
  image
      .resolve(ImageConfiguration.empty)
      .addListener(
        ImageStreamListener(
          (info, _) => done.complete(info),
          onError: (error, _) => done.complete(error),
        ),
      );
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('a failing host falls back to the next mirror', (tester) async {
    final asked = <String>[];
    final image = FallbackNetworkImage(
      [_primary, _mirror],
      client: MockClient((request) async {
        asked.add(request.url.host);
        return request.url.host == 'up.example'
            ? http.Response.bytes(tinyPng, 200)
            : http.Response('not found', 404);
      }),
    );
    final result = await tester.runAsync(() => _load(image));
    expect(result, isA<ImageInfo>());
    expect(asked, ['down.example', 'up.example']);
  });

  testWidgets('when every host fails, the placeholder stays', (tester) async {
    final image = FallbackNetworkImage([
      Uri.parse('https://a.example/x.jpg'),
      Uri.parse('https://b.example/x.jpg'),
    ], client: MockClient((_) async => http.Response('', 503)));
    final result = await tester.runAsync(() => _load(image));
    expect(result, isNot(isA<ImageInfo>()));
  });

  test('equal URL lists share one cache entry', () {
    expect(
      FallbackNetworkImage([_primary, _mirror]),
      FallbackNetworkImage([_primary, _mirror]),
    );
    expect(
      FallbackNetworkImage([_primary]),
      isNot(FallbackNetworkImage([_mirror])),
    );
  });
}
