import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/demo/demo_home_feed_source.dart';
import 'package:music_app/domain/home/home_feed.dart';

void main() {
  test('demo feed is flagged as demo and uses demo-only ids', () async {
    final result = await const DemoHomeFeedSource().load();

    final feed = (result as Ok<HomeFeed>).value;
    expect(feed.isDemo, isTrue);
    expect(feed.isEmpty, isFalse);
    final ids = [
      ...feed.recentlyAdded.map((a) => a.id.value),
      ...feed.albums.map((a) => a.id.value),
      ...feed.playlists.map((p) => p.id.value),
      feed.featured!.id.value,
    ];
    expect(ids, everyElement(startsWith('demo-')));
  });

  test('demo content has no artwork (no real covers)', () async {
    final result = await const DemoHomeFeedSource().load();

    final feed = (result as Ok<HomeFeed>).value;
    expect(
      [...feed.recentlyAdded, ...feed.albums].map((a) => a.artworkUri),
      everyElement(isNull),
    );
  });
}
