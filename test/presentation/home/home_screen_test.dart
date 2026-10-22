import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/presentation/design_system/design_system.dart';

import '../../helpers/aura_app_harness.dart';
import '../../helpers/fakes.dart';

void main() {
  testWidgets('demo content is shown with a visible demo label', (
    tester,
  ) async {
    await pumpAuraApp(tester);

    expect(find.text('Демо-данные'), findsOneWidget);
    expect(find.text('Хиты дня'), findsOneWidget);
    expect(find.text('Плейлист · 12 треков'), findsOneWidget);
    expect(find.text('Недавно прослушанное'), findsOneWidget);
  });

  testWidgets('demo cards are not presented as tappable', (tester) async {
    await pumpAuraApp(tester);

    expect(find.byType(AuraMediaCard), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(AuraMediaCard),
        matching: find.byType(AuraPressable),
      ),
      findsNothing,
    );
  });

  testWidgets('greeting follows the clock', (tester) async {
    await pumpAuraApp(tester, now: DateTime(2026, 1, 1, 20));

    expect(find.text('Добрый вечер'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton', (tester) async {
    final never = Completer<Result<HomeFeed>>();
    await pumpAuraApp(
      tester,
      homeFeedSource: FakeHomeFeedSource(() => never.future),
    );

    expect(find.byType(AuraSkeletonBox), findsWidgets);
    expect(find.text('Демо-данные'), findsNothing);
  });

  testWidgets('an error shows user text and retry reloads', (tester) async {
    final source = FakeHomeFeedSource(
      () async => const Err(NetworkFailure(debugMessage: 'timeout')),
    );
    await pumpAuraApp(tester, homeFeedSource: source);

    expect(find.text('Нет соединения'), findsOneWidget);
    expect(find.textContaining('timeout'), findsNothing);

    source.respond = () => const DemoHomeFeedSource().load();
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();

    expect(source.calls, 2);
    expect(find.text('Хиты дня'), findsOneWidget);
  });

  testWidgets('an empty feed shows the empty state without demo label', (
    tester,
  ) async {
    await pumpAuraApp(
      tester,
      homeFeedSource: FakeHomeFeedSource(
        () async => Ok(HomeFeed(recentlyPlayed: [], albums: [], playlists: [])),
      ),
    );

    expect(find.text('Здесь появится ваша музыка'), findsOneWidget);
    expect(find.text('Демо-данные'), findsNothing);
  });
}
