import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link_store.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_oembed.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_providers.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fake_providers.dart';
import '../../helpers/fakes.dart';

final _set = SoundCloudLink.parse(
  'https://soundcloud.com/forss/sets/soulhack',
)!;

String _msg(Map<String, Object?> m) => jsonEncode({'source': 'aura-sc', ...m});

void main() {
  late InMemorySoundCloudLinkStore store;
  late FakeLinkOpener links;
  late FakePlaybackController aura;
  SoundCloudPlayerController? widgetController;
  late List<Map<String, Object?>> sent;

  setUp(() {
    store = InMemorySoundCloudLinkStore();
    links = FakeLinkOpener();
    aura = FakePlaybackController(PlaybackSnapshot.initial);
    widgetController = null;
    sent = [];
  });

  SoundCloudOEmbed oEmbed() => SoundCloudOEmbed(
    JsonHttpClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({'title': 'Soulhack by Forss', 'author_name': 'Forss'}),
          ),
          200,
        ),
      ),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    bool hasWidget = true,
    InMemoryLibraryRepository? library,
  }) async {
    await pumpAuraApp(
      tester,
      library: library,
      overrides: [
        soundCloudLinkStoreProvider.overrideWithValue(store),
        soundCloudOEmbedProvider.overrideWithValue(oEmbed()),
        externalLinkOpenerProvider.overrideWithValue(links),
        playbackControllerProvider.overrideWithValue(aura),
        soundCloudWidgetBuilderProvider.overrideWithValue(
          hasWidget
              ? (link, controller) {
                  // Stands in for the web view: captures what AURA sends.
                  widgetController = controller..send = sent.add;
                  return const SizedBox.expand(key: Key('official-widget'));
                }
              : null,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(AuraTabBar))).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> widgetSays(WidgetTester tester, Map<String, Object?> m) async {
    widgetController!.handleMessage(_msg(m));
    await tester.pumpAndSettle();
  }

  testWidgets('Library offers SoundCloud', (tester) async {
    final library = InMemoryLibraryRepository();
    await library.addTracks([onlineTrack('1')]);
    await pump(tester, library: library);
    await go(tester, AppRoutes.library);
    await tester.tap(find.text(AuraStrings.savedLinks));
    await tester.pumpAndSettle();
    expect(find.text(AuraStrings.soundCloudEmptyTitle), findsOneWidget);
  });

  testWidgets('a pasted link is checked, saved and opened', (tester) async {
    await pump(tester);
    await go(tester, AppRoutes.librarySoundCloud);
    await tester.tap(find.text(AuraStrings.addLink).last);
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoTextField),
    );
    await tester.enterText(field, 'https://example.com/not-soundcloud');
    await tester.tap(find.text(AuraStrings.add));
    await tester.pumpAndSettle();
    expect(find.text(AuraStrings.soundCloudLinkInvalid), findsOneWidget);

    await tester.enterText(
      field,
      ' m.soundcloud.com/forss/sets/soulhack?si=x ',
    );
    await tester.tap(find.text(AuraStrings.add));
    await tester.pumpAndSettle();

    expect(await store.watch().first, [_set]);
    expect(find.byKey(const Key('official-widget')), findsOneWidget);
    expect(find.text('Soulhack by Forss'), findsOneWidget);
    expect(find.text(AuraStrings.soundCloudNote), findsOneWidget);
  });

  testWidgets('"Обзор музыки" opens the Discover page', (tester) async {
    await pump(tester);
    await go(tester, AppRoutes.librarySoundCloud);
    await tester.tap(find.text(AuraStrings.discoverMusic));
    await tester.pumpAndSettle();
    expect(links.opened, [Uri.parse('https://m.soundcloud.com/discover')]);
  });

  testWidgets('saved links are listed with their SoundCloud title', (
    tester,
  ) async {
    await store.add(_set);
    await pump(tester);
    await go(tester, AppRoutes.librarySoundCloud);
    expect(find.text('Soulhack by Forss'), findsOneWidget);
    expect(find.text('Forss'), findsOneWidget);
  });

  group('player', () {
    Future<void> open(WidgetTester tester) async {
      await pump(tester);
      await go(tester, AppRoutes.soundCloudPlayer(_set.url));
      await widgetSays(tester, {'type': 'ready'});
      await widgetSays(tester, {
        'type': 'sounds',
        'sounds': [
          {'title': 'Flickermood', 'author': 'Forss', 'durationMs': 213000},
          {'title': 'Journeyman', 'author': 'Forss'},
        ],
      });
    }

    testWidgets('lists the sounds and controls the official widget', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Flickermood'), findsOneWidget);
      expect(find.text('Journeyman'), findsOneWidget);

      await tester.tap(find.text('Journeyman'));
      await tester.tap(find.text(AuraStrings.playAll));
      await tester.pump();
      expect(sent, [
        {'target': 'aura-sc', 'type': 'skip', 'index': 1},
        {'target': 'aura-sc', 'type': 'play'},
      ]);
    });

    testWidgets('SoundCloud and AURA never play at the same time', (
      tester,
    ) async {
      await open(tester);
      await widgetSays(tester, {'type': 'play', 'index': 0});
      expect(aura.pauseCalls, 1);

      aura.emit(
        PlaybackSnapshot(
          queue: [onlineTrack('x')],
          currentIndex: 0,
          status: PlaybackStatus.playing,
        ),
      );
      await tester.pumpAndSettle();
      expect(sent.last, {'target': 'aura-sc', 'type': 'pause'});
    });

    testWidgets('a blocked page is explained', (tester) async {
      await open(tester);
      await widgetSays(tester, {'type': 'error'});
      expect(find.text(AuraStrings.soundCloudWidgetFailed), findsOneWidget);
    });

    testWidgets('"Open in SoundCloud" opens the original page', (tester) async {
      await open(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is AuraIconButton &&
              w.semanticLabel == AuraStrings.openOriginal,
        ),
      );
      await tester.pumpAndSettle();
      expect(links.opened, [_set.url]);
    });
  });

  testWidgets('without an embedded player the page says so', (tester) async {
    await pump(tester, hasWidget: false);
    await go(tester, AppRoutes.soundCloudPlayer(_set.url));
    expect(find.text(AuraStrings.soundCloudNoPlayer), findsOneWidget);
  });

  testWidgets('a broken link in the route shows "not found"', (tester) async {
    await pump(tester);
    await go(tester, '${AppRoutes.librarySoundCloud}/player?url=nonsense');
    expect(find.text(AuraStrings.soundCloudLinkInvalid), findsOneWidget);
  });
}
