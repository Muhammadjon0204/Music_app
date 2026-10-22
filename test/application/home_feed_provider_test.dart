import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/home/home_feed_provider.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/domain/home/home_feed.dart';

import '../helpers/fakes.dart';

void main() {
  // Plain test: awaiting provider futures needs real (not fake) async.
  test('returns the feed on success', () async {
    final feed = HomeFeed(recentlyAdded: [], albums: [], playlists: []);
    final source = FakeHomeFeedSource(() async => Ok(feed));
    final container = ProviderContainer.test(
      overrides: [
        homeFeedSourceProvider.overrideWithValue(source),
        libraryRepositoryProvider.overrideWithValue(
          InMemoryLibraryRepository(),
        ),
      ],
    );

    // Listen like a screen does: unlistened providers pause their
    // dependencies (including the library stream) in Riverpod 3.
    final subscription = container.listen(homeFeedProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(await container.read(homeFeedProvider.future), feed);
  });

  testWidgets('surfaces the AppFailure and does not auto-retry', (
    tester,
  ) async {
    final source = FakeHomeFeedSource(
      () async => const Err(StorageFailure(debugMessage: 'disk')),
    );
    final container = ProviderContainer.test(
      overrides: [
        homeFeedSourceProvider.overrideWithValue(source),
        libraryRepositoryProvider.overrideWithValue(
          InMemoryLibraryRepository(),
        ),
      ],
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
