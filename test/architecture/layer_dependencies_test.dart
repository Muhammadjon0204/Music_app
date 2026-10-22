import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the dependency rules from docs/ARCHITECTURE.md: `core` and `domain`
/// stay pure Dart and never depend on outer layers.
void main() {
  const outerLayers = [
    'package:music_app/app/',
    'package:music_app/application/',
    'package:music_app/presentation/',
    'package:music_app/data/',
    'package:music_app/audio/',
    'package:music_app/integrations/',
  ];
  const frameworkImports = [
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:riverpod/',
    'dart:ui',
    'dart:io',
  ];

  final rules = <String, List<String>>{
    'lib/core': [
      ...frameworkImports,
      ...outerLayers,
      'package:music_app/domain/',
    ],
    'lib/domain': [...frameworkImports, ...outerLayers],
    // State and use cases: no UI toolkit, no knowledge of implementations.
    'lib/application': [
      'package:flutter/',
      'dart:ui',
      'dart:io',
      'package:music_app/app/',
      'package:music_app/presentation/',
      'package:music_app/data/',
      'package:music_app/audio/',
      'package:music_app/integrations/',
    ],
    // Audio playback: implements domain contracts over plugins, no UI.
    'lib/audio': [
      'package:flutter/material.dart',
      'package:flutter/cupertino.dart',
      'package:flutter/widgets.dart',
      'package:music_app/app/',
      'package:music_app/application/',
      'package:music_app/presentation/',
      'package:music_app/data/',
    ],
    // Implementations of domain contracts.
    'lib/data': [
      'package:flutter/material.dart',
      'package:flutter/cupertino.dart',
      'package:flutter/widgets.dart',
      'package:music_app/app/',
      'package:music_app/application/',
      'package:music_app/presentation/',
    ],
  };

  final directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  for (final MapEntry(key: dir, value: forbidden) in rules.entries) {
    test('$dir has no forbidden imports', () {
      final violations = <String>[];
      final files = Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty, reason: 'No Dart files found in $dir');

      for (final file in files) {
        for (final line in file.readAsLinesSync()) {
          final uri = directive.firstMatch(line)?.group(1);
          if (uri != null && forbidden.any(uri.startsWith)) {
            violations.add('${file.path}: $uri');
          }
        }
      }

      expect(violations, isEmpty);
    });
  }
}
