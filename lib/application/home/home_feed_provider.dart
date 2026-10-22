import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/domain/home/home_feed.dart';

/// Bound at the composition root (main.dart) and in tests.
final homeFeedSourceProvider = Provider<HomeFeedSource>(
  (ref) => throw UnimplementedError(
    'homeFeedSourceProvider must be overridden at the composition root',
  ),
  retry: (_, _) => null,
);

/// Home content. A failure surfaces as an [AsyncError] holding the
/// AppFailure; the user retries explicitly instead of silent auto-retries.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  // Built from the loaded library, and rebuilt whenever it changes
  // (imports, favorites, playlists) — not before it is ready.
  await ref.watch(librarySnapshotProvider.future);
  final result = await ref.watch(homeFeedSourceProvider).load();
  switch (result) {
    case Ok(:final value):
      return value;
    case Err(:final failure):
      ref.read(appLoggerProvider).warning('Home feed failed: $failure');
      throw failure;
  }
}, retry: (_, _) => null);
