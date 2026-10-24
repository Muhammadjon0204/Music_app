import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link_store.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_oembed.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/widget_view/bridge_page.dart';
import 'package:sembast/sembast_memory.dart';

String? _parsed(String input) => SoundCloudLink.parse(input)?.url.toString();

String _msg(Map<String, Object?> m) => jsonEncode({'source': 'aura-sc', ...m});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('links', () {
    test('accepts track, playlist, profile and likes pages', () {
      expect(
        _parsed('https://soundcloud.com/forss/flickermood'),
        'https://soundcloud.com/forss/flickermood',
      );
      expect(
        _parsed('https://soundcloud.com/forss/sets/soulhack'),
        'https://soundcloud.com/forss/sets/soulhack',
      );
      expect(
        _parsed('https://soundcloud.com/forss'),
        'https://soundcloud.com/forss',
      );
      expect(
        _parsed('https://soundcloud.com/forss/likes'),
        'https://soundcloud.com/forss/likes',
      );
    });

    test('normalizes what people paste', () {
      expect(
        _parsed(
          '  http://m.soundcloud.com/forss/flickermood?utm_source=x#t=1 ',
        ),
        'https://soundcloud.com/forss/flickermood',
      );
      expect(
        _parsed('www.soundcloud.com/forss'),
        'https://soundcloud.com/forss',
      );
      expect(
        _parsed('https://on.soundcloud.com/AbC12'),
        'https://on.soundcloud.com/AbC12',
      );
    });

    test('keeps the secret token of a private link', () {
      expect(
        _parsed('https://soundcloud.com/me/private-mix/s-AbCdE12'),
        'https://soundcloud.com/me/private-mix/s-AbCdE12',
      );
    });

    test('refuses everything that is not a SoundCloud music page', () {
      for (final input in [
        '',
        'hello',
        'https://soundcloud.com/',
        'https://soundcloud.com/discover',
        'https://soundcloud.com/you/likes',
        'https://soundcloud.com.evil.example/forss',
        'https://evil.example/soundcloud.com/forss',
        'https://user:pass@soundcloud.com/forss',
        'ftp://soundcloud.com/forss',
        'javascript:alert(1)',
      ]) {
        expect(SoundCloudLink.parse(input), isNull, reason: input);
      }
    });

    test('the widget URL is the official player, without autoplay', () {
      final widget = SoundCloudLink.parse(
        'https://soundcloud.com/forss/sets/soulhack',
      )!.widgetUrl;
      expect(widget.host, 'w.soundcloud.com');
      expect(widget.path, '/player/');
      expect(
        widget.queryParameters['url'],
        'https://soundcloud.com/forss/sets/soulhack',
      );
      expect(widget.queryParameters['auto_play'], 'false');
    });
  });

  group('oEmbed', () {
    late List<Uri> requests;
    SoundCloudOEmbed oEmbed(http.Response Function() respond) =>
        SoundCloudOEmbed(
          JsonHttpClient(
            client: MockClient((request) async {
              requests.add(request.url);
              return respond();
            }),
            retryDelay: Duration.zero,
          ),
        );
    setUp(() => requests = []);
    final link = SoundCloudLink.parse(
      'https://soundcloud.com/forss/sets/soulhack',
    )!;

    test('reads title, author and cover', () async {
      final result = await oEmbed(
        () => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'title': 'Soulhack by Forss',
              'author_name': 'Forss',
              'thumbnail_url': 'https://i1.sndcdn.com/a-t500x500.jpg',
              'html': '<iframe src="x"></iframe>',
            }),
          ),
          200,
        ),
      ).info(link);
      final info = (result as Ok<SoundCloudPageInfo>).value;
      expect(info.title, 'Soulhack by Forss');
      expect(info.author, 'Forss');
      expect(info.artwork, Uri.parse('https://i1.sndcdn.com/a-t500x500.jpg'));
      expect(requests.single.host, 'soundcloud.com');
      expect(requests.single.path, '/oembed');
      expect(requests.single.queryParameters['url'], '${link.url}');
    });

    test('a private or removed page is "not found"', () async {
      final result = await oEmbed(() => http.Response('', 404)).info(link);
      expect((result as Err).failure, isA<NotFoundFailure>());
    });

    test(
      'an answer without a title is invalid; http covers are dropped',
      () async {
        final noTitle = await oEmbed(
          () => http.Response(jsonEncode({'author_name': 'x'}), 200),
        ).info(link);
        expect((noTitle as Err).failure, isA<InvalidResponseFailure>());

        final insecure = await oEmbed(
          () => http.Response(
            jsonEncode({
              'title': 'T',
              'thumbnail_url': 'http://x.example/a.jpg',
            }),
            200,
          ),
        ).info(link);
        expect((insecure as Ok<SoundCloudPageInfo>).value.artwork, isNull);
      },
    );
  });

  group('saved links', () {
    final a = SoundCloudLink.parse('https://soundcloud.com/a')!;
    final b = SoundCloudLink.parse('https://soundcloud.com/b/sets/c')!;
    final stores = <String, Future<SoundCloudLinkStore> Function()>{
      'in memory': () async => InMemorySoundCloudLinkStore(),
      'sembast': () async => SembastSoundCloudLinkStore(
        await newDatabaseFactoryMemory().openDatabase('t.db'),
      ),
    };
    for (final MapEntry(key: name, value: create) in stores.entries) {
      test('$name: newest first, no duplicates, removable', () async {
        final store = await create();
        await store.add(a);
        await store.add(b);
        await store.add(a);
        expect(await store.watch().first, [a, b]);
        await store.remove(a);
        expect(await store.watch().first, [b]);
      });
    }
  });

  group('player controller', () {
    late List<Map<String, Object?>> sent;
    late int startedPlaying;
    late SoundCloudPlayerController player;

    setUp(() {
      sent = [];
      startedPlaying = 0;
      player = SoundCloudPlayerController(
        onStartedPlaying: () => startedPlaying++,
      )..send = sent.add;
    });

    test('commands wait until the widget is ready', () {
      player.play();
      expect(sent, isEmpty);
      player.handleMessage(_msg({'type': 'ready'}));
      player.play();
      expect(sent.single, {'target': 'aura-sc', 'type': 'play'});
    });

    test('lists the sounds the widget reports, also half-loaded ones', () {
      player.handleMessage(
        _msg({
          'type': 'sounds',
          'sounds': [
            {
              'title': 'Flickermood',
              'author': 'Forss',
              'artwork': 'https://i1.sndcdn.com/x.jpg',
              'durationMs': 213000,
              'url': 'https://soundcloud.com/forss/flickermood',
            },
            {'title': null},
            'garbage',
          ],
        }),
      );
      expect(player.sounds, hasLength(2));
      expect(player.sounds.first.title, 'Flickermood');
      expect(player.sounds.first.duration, const Duration(seconds: 213));
      expect(player.sounds.last.title, isNull);
    });

    test('playing in the widget pauses AURA once; state follows', () {
      player.handleMessage(_msg({'type': 'play', 'index': 2}));
      player.handleMessage(
        _msg({'type': 'progress', 'positionMs': 5000, 'index': 2}),
      );
      expect(player.isPlaying, isTrue);
      expect(player.currentIndex, 2);
      expect(player.position, const Duration(seconds: 5));
      expect(startedPlaying, 1);

      player.handleMessage(_msg({'type': 'pause'}));
      expect(player.isPlaying, isFalse);
      player.handleMessage(_msg({'type': 'play', 'index': 2}));
      expect(startedPlaying, 2);
    });

    test('an error is reported and stops playback', () {
      player.handleMessage(_msg({'type': 'play', 'index': 0}));
      player.handleMessage(_msg({'type': 'error'}));
      expect(player.hasFailed, isTrue);
      expect(player.isPlaying, isFalse);
    });

    test('foreign or malformed messages are ignored', () {
      var changes = 0;
      player.addListener(() => changes++);
      for (final raw in [
        'not json',
        jsonEncode({'type': 'play'}),
        jsonEncode({'source': 'other', 'type': 'play'}),
        _msg({'type': 'unknown'}),
        jsonEncode([1, 2]),
      ]) {
        player.handleMessage(raw);
      }
      expect(changes, 0);
      expect(player.isPlaying, isFalse);
    });

    test('skip only to sounds that exist', () {
      player.handleMessage(_msg({'type': 'ready'}));
      player.handleMessage(
        _msg({
          'type': 'sounds',
          'sounds': [
            {'title': 'a'},
            {'title': 'b'},
          ],
        }),
      );
      player.skipTo(5);
      player.skipTo(1);
      expect(sent, [
        {'target': 'aura-sc', 'type': 'skip', 'index': 1},
      ]);
    });
  });

  group('bridge page', () {
    final html = File('assets/soundcloud/bridge.html').readAsStringSync();

    test('loads only the official widget API', () {
      final scripts = RegExp(r'<script[^>]*src="([^"]+)"').allMatches(html);
      expect(scripts.map((m) => m.group(1)), [
        'https://w.soundcloud.com/player/api.js',
      ]);
      expect(html, contains('{{WIDGET_URL}}'));
    });

    test('only accepts commands from the page that embeds it', () {
      expect(html, contains('event.source !== window.parent'));
      expect(html, contains("command.target !== 'aura-sc'"));
    });

    test('the widget URL is inserted escaped', () async {
      final page = await loadBridgePage(
        SoundCloudLink.parse('https://soundcloud.com/forss/sets/soulhack')!,
      );
      expect(page, isNot(contains('{{WIDGET_URL}}')));
      expect(page, contains('src="https://w.soundcloud.com/player/?url='));
      expect(page, contains('&amp;auto_play=false'));
    });
  });
}
