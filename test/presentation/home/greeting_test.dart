import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/home/greeting.dart';

void main() {
  String at(int hour) => greetingFor(DateTime(2026, 1, 1, hour));

  test('greeting follows the time of day, including boundaries', () {
    expect(at(4), 'Доброй ночи');
    expect(at(5), 'Доброе утро');
    expect(at(11), 'Доброе утро');
    expect(at(12), 'Добрый день');
    expect(at(16), 'Добрый день');
    expect(at(17), 'Добрый вечер');
    expect(at(22), 'Добрый вечер');
    expect(at(23), 'Доброй ночи');
    expect(at(0), 'Доброй ночи');
  });
}
