import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/home/home_feed.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('returns the feed on success', (tester) async {
    final feed = HomeFeed(recentlyPlayed: [], albums: [], playlists: []);
    final source = FakeHomeFeedSource(() async => Ok(feed));
    final container = ProviderContainer.test(
      overrides: [homeFeedSourceProvider.overrideWithValue(source)],
    );

    expect(await container.read(homeFeedProvider.future), feed);
  });

  testWidgets('surfaces the AppFailure and does not auto-retry', (
    tester,
  ) async {
    final source = FakeHomeFeedSource(
      () async => const Err(StorageFailure(debugMessage: 'disk')),
    );
    final container = ProviderContainer.test(
      overrides: [homeFeedSourceProvider.overrideWithValue(source)],
    );
    final subscription = container.listen(homeFeedProvider, (_, _) {});
    addTearDown(subscription.close);

    await tester.pump();
    expect(container.read(homeFeedProvider).error, isA<StorageFailure>());

    // Riverpod's default retry would fire within seconds.
    await tester.pump(const Duration(seconds: 10));
    expect(source.calls, 1);
  });
}
