import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/common/duration_format.dart';

void main() {
  test('formats minutes and seconds', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 46)), '3:46');
    expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
  });

  test('adds hours from one hour', () {
    expect(formatDuration(const Duration(hours: 1, seconds: 3)), '1:00:03');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 5, seconds: 9)),
      '2:05:09',
    );
  });

  test('truncates partial seconds', () {
    expect(formatDuration(const Duration(milliseconds: 3999)), '0:03');
  });

  test('shows negative values as zero', () {
    expect(formatDuration(const Duration(seconds: -4)), '0:00');
  });
}
