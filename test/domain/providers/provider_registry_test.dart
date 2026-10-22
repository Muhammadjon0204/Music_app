import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../../helpers/fake_providers.dart';

class _BadIdProvider implements MusicProvider {
  @override
  ProviderId get id => const ProviderId('a:b');

  @override
  String get displayName => 'Bad';
}

void main() {
  final streaming = FakeStreamingProvider(
    (_) async => throw UnimplementedError(),
  );
  final registry = ProviderRegistry([streaming, const LinkOnlyProvider()]);

  test('a supported capability is returned', () {
    final result = registry.capability<StreamingProvider>(
      const ProviderId('fake'),
    );
    expect((result as Ok).value, same(streaming));
  });

  test('a missing capability is a failure, not an exception', () {
    final result = registry.capability<SearchableProvider>(
      const ProviderId('links'),
    );
    expect((result as Err).failure, isA<FeatureUnavailableFailure>());
  });

  test('an unknown provider is a failure', () {
    final result = registry.capability<StreamingProvider>(
      const ProviderId('nope'),
    );
    expect((result as Err).failure, isA<FeatureUnavailableFailure>());
  });

  test('local music needs no providers', () {
    expect(ProviderRegistry.empty.all, isEmpty);
  });

  test('provider IDs with ":" are rejected (they prefix track IDs)', () {
    expect(() => ProviderRegistry([_BadIdProvider()]), throwsArgumentError);
  });

  test('pages know whether more results exist', () {
    expect(ProviderPage(items: const [1], nextOffset: 20).hasMore, isTrue);
    expect(ProviderPage(items: const [1]).hasMore, isFalse);
  });
}
