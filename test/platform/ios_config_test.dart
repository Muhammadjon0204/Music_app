import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS settings the app relies on but no Dart test would otherwise notice
/// missing until someone tests on a device.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('background audio is declared, and only audio', () {
    final modes = RegExp(
      r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(modes, isNotNull, reason: 'Music would stop when the app hides');
    final values = RegExp(r'<string>(.*?)</string>')
        .allMatches(modes!.group(1)!)
        .map((m) => m.group(1))
        .toList();
    // Extra modes need App Store justification.
    expect(values, ['audio']);
  });

  test('no media library or microphone permission is requested', () {
    // Import uses the Files picker, which needs no permission.
    expect(plist, isNot(contains('NSAppleMusicUsageDescription')));
    expect(plist, isNot(contains('NSMicrophoneUsageDescription')));
  });
}
