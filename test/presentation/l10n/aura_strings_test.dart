import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

void main() {
  test('Russian plural forms for track counts', () {
    const cases = {
      0: '0 треков',
      1: '1 трек',
      2: '2 трека',
      4: '4 трека',
      5: '5 треков',
      11: '11 треков',
      12: '12 треков',
      14: '14 треков',
      21: '21 трек',
      22: '22 трека',
      62: '62 трека',
      100: '100 треков',
      101: '101 трек',
      111: '111 треков',
      112: '112 треков',
    };
    for (final MapEntry(key: count, value: expected) in cases.entries) {
      expect(AuraStrings.trackCount(count), expected, reason: '$count');
    }
  });
}
