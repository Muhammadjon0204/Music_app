import 'dart:async';

import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:sembast/sembast.dart';

/// The SoundCloud links the user saved, newest first. Stores only URLs.
abstract interface class SoundCloudLinkStore {
  Stream<List<SoundCloudLink>> watch();

  Future<Result<void>> add(SoundCloudLink link);

  Future<Result<void>> remove(SoundCloudLink link);
}

/// In the library's database file (a new store; nothing else changes).
final class SembastSoundCloudLinkStore implements SoundCloudLinkStore {
  SembastSoundCloudLinkStore(this._db);

  final Database _db;
  final _links = stringMapStoreFactory.store('soundcloud_links');
  int _lastStamp = 0;

  @override
  Stream<List<SoundCloudLink>> watch() => _links
      .query(finder: Finder(sortOrders: [SortOrder('at', false)]))
      .onSnapshots(_db)
      .map(
        (records) => [for (final r in records) ?SoundCloudLink.parse(r.key)],
      );

  @override
  Future<Result<void>> add(SoundCloudLink link) => _guard(
    () => _links.record(link.url.toString()).put(_db, {'at': _stamp()}),
  );

  @override
  Future<Result<void>> remove(SoundCloudLink link) =>
      _guard(() => _links.record(link.url.toString()).delete(_db));

  /// Strictly increasing, so links saved in the same millisecond keep
  /// their order.
  int _stamp() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  static Future<Result<void>> _guard(Future<Object?> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } on Object catch (e, stackTrace) {
      return Err(
        StorageFailure(
          debugMessage: 'SoundCloud links: $e',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

/// In memory: web, fallback, tests.
final class InMemorySoundCloudLinkStore implements SoundCloudLinkStore {
  final _changes = StreamController<List<SoundCloudLink>>.broadcast();
  final _links = <SoundCloudLink>[];

  @override
  Stream<List<SoundCloudLink>> watch() async* {
    yield List.unmodifiable(_links);
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> add(SoundCloudLink link) async {
    _links
      ..remove(link)
      ..insert(0, link);
    _changes.add(List.unmodifiable(_links));
    return const Ok(null);
  }

  @override
  Future<Result<void>> remove(SoundCloudLink link) async {
    _links.remove(link);
    _changes.add(List.unmodifiable(_links));
    return const Ok(null);
  }
}
