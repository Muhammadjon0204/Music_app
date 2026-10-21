import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Colors are defined once, in design system tokens. Everywhere else in the
/// UI they must come from `context.auraColors`.
void main() {
  test('presentation code uses color tokens only', () {
    const tokensDir = 'lib/presentation/design_system/tokens';
    final forbidden = RegExp(r'\bColor\(0x|\bColors\.(?!transparent\b)');

    final files = Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll(r'\', '/').startsWith(tokensDir))
        .toList();
    expect(files, isNotEmpty);

    final violations = <String>[
      for (final file in files)
        for (final (i, line) in file.readAsLinesSync().indexed)
          if (forbidden.hasMatch(line)) '${file.path}:${i + 1}: ${line.trim()}',
    ];

    expect(violations, isEmpty);
  });
}
