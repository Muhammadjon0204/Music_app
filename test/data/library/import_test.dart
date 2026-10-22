import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/file_track_importer.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/io_missing_file_checker.dart';
import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/data/library/tag_reader.dart';
import 'package:music_app/domain/library/import.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:path/path.dart' as p;

import '../../helpers/audio_fixtures.dart';

void main() {
  late Directory temp;
  late Directory incoming;
  late LibraryPaths paths;
  late InMemoryLibraryRepository repo;
  late FileTrackImporter importer;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('aura_import_');
    incoming = await Directory(p.join(temp.path, 'incoming')).create();
    paths = LibraryPaths(p.join(temp.path, 'library'));
    repo = InMemoryLibraryRepository();
    importer = FileTrackImporter(repository: repo, paths: paths);
  });

  tearDown(() => temp.delete(recursive: true));

  PickedAudioFile pick(String name, List<int> bytes) {
    final file = File(p.join(incoming.path, name))..writeAsBytesSync(bytes);
    return PickedAudioFile(path: file.path, name: name);
  }

  group('importing', () {
    test('reads Cyrillic tags and a cover from a real MP3', () async {
      final report = await importer.importFiles([
        pick(
          'song.mp3',
          buildMp3(
            title: 'Группа крови',
            artist: 'Кино',
            album: 'Группа крови',
            track: '1/11',
            year: '1988',
            coverPng: tinyPng,
          ),
        ),
      ]);

      final track = report.imported.single;
      expect(track.title, 'Группа крови');
      expect(track.artistName, 'Кино');
      expect(track.albumTitle, 'Группа крови');
      expect(track.trackNumber, 1);
      expect(track.year, 1988);
      expect(track.artworkUri.toString(), startsWith('library:artwork/'));
      expect(repo.current.tracks.single.id, track.id);
    });

    test(
      'copies the file under a content name and stores a reference',
      () async {
        final picked = pick('My Song.mp3', buildMp3(title: 'T'));
        final track = (await importer.importFiles([picked])).imported.single;

        final ref = (track.sources.single as LocalFileSource).fileReference;
        expect(ref, startsWith('library:audio/'));
        expect(ref, isNot(contains(temp.path)));

        // The picker's temporary copy can disappear; the library keeps working.
        await File(picked.path).delete();
        expect(File(paths.resolve(ref)!).existsSync(), isTrue);
      },
    );

    test('untagged files are titled after the file name', () async {
      final report = await importer.importFiles([
        pick('Мой трек 01.wav', List.filled(100, 7)),
      ]);
      final track = report.imported.single;
      expect(track.title, 'Мой трек 01');
      expect(track.artistName, isNull);
      expect(track.albumTitle, isNull);
    });

    test('the same audio under another name is a duplicate', () async {
      final bytes = buildMp3(title: 'Same');
      await importer.importFiles([pick('a.mp3', bytes)]);

      final report = await importer.importFiles([
        pick('b.mp3', bytes),
        pick('c.mp3', bytes),
      ]);

      expect(report.imported, isEmpty);
      expect(report.duplicates, 2);
      expect(repo.current.tracks, hasLength(1));
    });

    test('duplicates within one batch are imported once', () async {
      final bytes = buildMp3(title: 'Twice');
      final report = await importer.importFiles([
        pick('one.mp3', bytes),
        pick('two.mp3', bytes),
      ]);
      expect(report.imported, hasLength(1));
      expect(report.skipped, {'two.mp3': ImportSkipReason.duplicate});
    });

    test('unsupported formats are reported and not copied', () async {
      final report = await importer.importFiles([
        pick('song.ogg', [1, 2, 3]),
        pick('notes.txt', [1, 2, 3]),
      ]);
      expect(report.skipped.values, everyElement(ImportSkipReason.unsupported));
      expect(Directory(paths.audioDir).listSync(), isEmpty);
    });

    test('a vanished source file is reported as unreadable', () async {
      final report = await importer.importFiles([
        PickedAudioFile(
          path: p.join(incoming.path, 'gone.mp3'),
          name: 'gone.mp3',
        ),
        pick('ok.mp3', buildMp3(title: 'Ok')),
      ]);
      expect(report.skipped, {'gone.mp3': ImportSkipReason.unreadable});
      expect(report.imported.single.title, 'Ok');
    });

    test('an album cover is stored once', () async {
      await importer.importFiles([
        pick('1.mp3', buildMp3(title: '1', coverPng: tinyPng)),
        pick('2.mp3', buildMp3(title: '2', coverPng: tinyPng)),
      ]);
      expect(Directory(paths.artworkDir).listSync(), hasLength(1));
    });

    test('reports progress for every file', () async {
      final progress = <(int, int)>[];
      await importer.importFiles([
        pick('1.mp3', buildMp3(title: '1')),
        pick('2.mp3', buildMp3(title: '2')),
        pick('3.txt', [0]),
      ], onProgress: (done, total) => progress.add((done, total)));
      expect(progress, [(1, 3), (2, 3), (3, 3)]);
    });
  });

  group('tag reader', () {
    test('garbage never throws and yields no tags', () async {
      final file = File(p.join(temp.path, 'junk.mp3'))
        ..writeAsBytesSync(Uint8List.fromList(List.generate(5000, (i) => i)));
      final tags = AudioMetadataTagReader.readSync(file.path);
      expect(tags.title, isNull);
    });

    test('a real MP3 yields a plausible duration when reported', () {
      final file = File(p.join(temp.path, 'd.mp3'))
        ..writeAsBytesSync(buildMp3(title: 'D', frames: 400));
      final duration = AudioMetadataTagReader.readSync(file.path).duration;
      if (duration != null) {
        expect(duration.inMilliseconds, closeTo(10450, 1500));
      }
    });

    test('NUL padding and blanks are cleaned', () {
      expect(AudioMetadataTagReader.clean('Title\u0000\u0000 '), 'Title');
      expect(AudioMetadataTagReader.clean('  '), isNull);
    });
  });

  group('paths and missing files', () {
    test('references cannot escape the library folder', () {
      expect(paths.resolve('library:audio/a.mp3'), isNotNull);
      for (final evil in [
        'library:../secret',
        'library:audio/../../x',
        'library:/etc/passwd',
        'library:audio//a',
        '/abs/path.mp3',
      ]) {
        expect(paths.resolve(evil), isNull, reason: evil);
      }
    });

    test(
      'a deleted copy is reported missing and plays as a file error',
      () async {
        final track = (await importer.importFiles([
          pick('x.mp3', buildMp3(title: 'X')),
        ])).imported.single;
        final ref = (track.sources.single as LocalFileSource).fileReference;

        final checker = IoMissingFileChecker(paths);
        expect(await checker.findMissing([track]), isEmpty);

        await File(paths.resolve(ref)!).delete();
        expect(await checker.findMissing([track]), {track.id});

        final resolved = resolveTrackAudio(
          track,
          resolveFile: paths.resolve,
          fileExists: (path) => File(path).existsSync(),
        );
        expect((resolved as Err).failure, isA<FileAccessFailure>());
      },
    );

    test('an existing copy resolves to an absolute file location', () async {
      final track = (await importer.importFiles([
        pick('y.mp3', buildMp3(title: 'Y')),
      ])).imported.single;
      final resolved = resolveTrackAudio(track, resolveFile: paths.resolve);
      final location = (resolved as Ok<AudioLocation>).value as FileAudio;
      expect(p.isAbsolute(location.path), isTrue);
    });
  });
}
