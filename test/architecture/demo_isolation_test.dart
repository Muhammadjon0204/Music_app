import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Demo data may only be wired in at the composition root, so it can never
/// leak into screens or state and is removed in one place.
void main() {
  test('only main.dart imports demo data', () {
    final importers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll(r'\', '/').startsWith('lib/data/demo'))
        .where((f) => f.readAsStringSync().contains('/data/demo/'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();

    expect(importers, ['lib/main.dart']);
  });
}
