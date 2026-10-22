import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

import '../helpers/aura_app_harness.dart';
import '../helpers/fakes.dart';

Album album(int i, {String? title, String? artist = 'Artist'}) =>
    Album(id: AlbumId('a$i'), title: title ?? 'Album $i', artistName: artist);

Playlist playlist(String name, int tracks) => Playlist(
  id: PlaylistId(name),
  name: name,
  trackIds: [for (var i = 0; i < tracks; i++) TrackId('$name-$i')],
);

FakeHomeFeedSource feedOf(HomeFeed feed) =>
    FakeHomeFeedSource(() async => Ok(feed));

void main() {
  testWidgets('only a featured playlist: banner, no sections', (tester) async {
    await pumpAuraApp(
      tester,
      homeFeedSource: feedOf(
        HomeFeed(
          featured: playlist('Только баннер', 3),
          recentlyAdded: [],
          albums: [],
          playlists: [],
        ),
      ),
    );

    expect(find.text('Только баннер'), findsOneWidget);
    expect(find.text('Плейлист · 3 трека'), findsOneWidget);
    expect(find.byType(AuraSectionHeader), findsNothing);
  });

  testWidgets('missing artist shows "Неизвестный исполнитель"', (tester) async {
    await pumpAuraApp(
      tester,
      homeFeedSource: feedOf(
        HomeFeed(
          recentlyAdded: [album(1, artist: null)],
          albums: [],
          playlists: [],
        ),
      ),
    );

    expect(find.text('Неизвестный исполнитель'), findsOneWidget);
  });

  testWidgets('very long titles are truncated, never overflow', (tester) async {
    final long = 'Очень длинное название ' * 10;
    await pumpAuraApp(
      tester,
      device: iPhoneSE,
      textScale: 2,
      homeFeedSource: feedOf(
        HomeFeed(
          featured: playlist(long, 12345),
          recentlyAdded: [album(1, title: long, artist: long)],
          albums: [album(2, title: long)],
          playlists: [playlist('$long 2', 1)],
        ),
      ),
    );

    expect(find.text('Плейлист · 12345 треков'), findsOneWidget);
  });

  testWidgets('carousels are capped at 10 items', (tester) async {
    await pumpAuraApp(
      tester,
      homeFeedSource: feedOf(
        HomeFeed(
          recentlyAdded: [],
          albums: [for (var i = 0; i < 25; i++) album(i)],
          playlists: [],
        ),
      ),
    );

    expect(find.byType(AuraMediaCard), findsNWidgets(10));
  });

  testWidgets('unexpected exception shows generic text, no details', (
    tester,
  ) async {
    await pumpAuraApp(
      tester,
      homeFeedSource: FakeHomeFeedSource(
        () async => throw StateError('секретная деталь'),
      ),
    );

    expect(find.text('Что-то пошло не так'), findsOneWidget);
    expect(find.textContaining('секретная'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('every failure type shows its own message on Home', (
    tester,
  ) async {
    const failures = <AppFailure>[
      FileAccessFailure(),
      UnsupportedMediaFailure(),
      PermissionDeniedFailure(),
      NetworkFailure(),
      StorageFailure(),
      PlaybackFailure(),
      UnexpectedFailure(),
    ];
    for (final failure in failures) {
      await pumpAuraApp(
        tester,
        homeFeedSource: FakeHomeFeedSource(() async => Err(failure)),
      );
      final (title, message) = failureText(failure);
      expect(find.text(title), findsOneWidget, reason: '$failure');
      expect(find.text(message), findsOneWidget, reason: '$failure');
    }
  });

  testWidgets('retry that fails again shows the error again', (tester) async {
    final source = FakeHomeFeedSource(() async => const Err(NetworkFailure()));
    await pumpAuraApp(tester, homeFeedSource: source);

    for (var attempt = 2; attempt <= 4; attempt++) {
      await tester.tap(find.text('Повторить'));
      await tester.pump();
      await tester.pump();
      expect(source.calls, attempt);
      expect(find.text('Нет соединения'), findsOneWidget);
    }
  });

  testWidgets('slow load shows a skeleton, then the content', (tester) async {
    final pending = Completer<Result<HomeFeed>>();
    await pumpAuraApp(
      tester,
      homeFeedSource: FakeHomeFeedSource(() => pending.future),
    );
    expect(find.byType(AuraSkeletonBox), findsWidgets);

    pending.complete(
      Ok(HomeFeed(recentlyAdded: [album(1)], albums: [], playlists: [])),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AuraSkeletonBox), findsNothing);
    expect(find.text('Album 1'), findsOneWidget);
  });
}
