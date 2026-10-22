import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the library keeps its files.
///
/// The database stores `library:` references relative to [root], never
/// absolute paths: on iOS the app container path changes across updates.
final class LibraryPaths {
  const LibraryPaths(this.root);

  static const scheme = 'library:';

  final String root;

  static Future<LibraryPaths> forApp() async {
    final support = await getApplicationSupportDirectory();
    return LibraryPaths(p.join(support.path, 'library'));
  }

  String get databasePath => p.join(root, 'library.db');

  String get audioDir => p.join(root, 'audio');

  String get artworkDir => p.join(root, 'artwork');

  /// Reference for a file under [root], e.g. `library:audio/ab12.mp3`.
  static String reference(String relativePath) =>
      '$scheme${relativePath.replaceAll(r'\', '/')}';

  /// Absolute path for a `library:` reference, or null when [reference] is
  /// not one or tries to escape [root].
  String? resolve(String reference) {
    if (!reference.startsWith(scheme)) return null;
    final segments = reference.substring(scheme.length).split('/');
    if (segments.any((s) => s.isEmpty || s == '.' || s == '..')) return null;
    return p.joinAll([root, ...segments]);
  }
}
