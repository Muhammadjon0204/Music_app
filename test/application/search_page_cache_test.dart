import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';

void main() {
  const audius = ProviderId('audius');
  late DateTime now;
  late SearchPageCache cache;

  setUp(() {
    now = DateTime(2026, 10, 25, 12);
    cache = SearchPageCache(now: () => now);
  });

  test('a page is found by provider, query (any case) and offset', () {
    final page = ProviderPage(items: [onlineTrack('1')]);
    cache.put(audius, 'Night City', 0, page);
    expect(cache.get(audius, ' night city ', 0), same(page));
    expect(cache.get(audius, 'night city', 20), isNull);
    expect(cache.get(const ProviderId('jamendo'), 'night city', 0), isNull);
  });

  test('pages expire', () {
    cache.put(audius, 'x', 0, ProviderPage(items: [onlineTrack('1')]));
    now = now.add(SearchPageCache.ttl);
    expect(cache.get(audius, 'x', 0), isNull);
  });

  test('only the newest pages are kept', () {
    for (var i = 0; i <= SearchPageCache.maxPages; i++) {
      cache.put(audius, 'q$i', 0, ProviderPage(items: [onlineTrack('$i')]));
    }
    expect(cache.get(audius, 'q0', 0), isNull);
    expect(cache.get(audius, 'q${SearchPageCache.maxPages}', 0), isNotNull);
  });
}
