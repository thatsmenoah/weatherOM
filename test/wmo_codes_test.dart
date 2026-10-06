import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/utils/wmo_codes.dart';
import 'package:weather_app/core/locale_manager.dart';

void main() {
  group('иконки', () {
    test('день и ночь отличаются суффиксом', () {
      expect(WmoCodes.icon(0), '01d');
      expect(WmoCodes.icon(0, isDay: false), '01n');
      expect(WmoCodes.icon(95, isDay: false), '11n');
    });

    test('диапазоны кодов схлопываются в одну иконку', () {
      // 51–57 (морось) и 61–67 (дождь) — одна иконка.
      for (final code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67]) {
        expect(WmoCodes.icon(code), '10d', reason: 'код $code');
      }
      // 71–77 (снег) и 85–86 (снегопад).
      for (final code in [71, 73, 75, 77, 85, 86]) {
        expect(WmoCodes.icon(code), '13d', reason: 'код $code');
      }
      // 80–82 (ливень).
      for (final code in [80, 81, 82]) {
        expect(WmoCodes.icon(code), '09d', reason: 'код $code');
      }
      // 45–48 (туман).
      for (final code in [45, 48]) {
        expect(WmoCodes.icon(code), '50d', reason: 'код $code');
      }
    });

    test('неизвестный код не ломает и даёт ясное небо', () {
      expect(WmoCodes.icon(-1), '01d');
      expect(WmoCodes.icon(1234), '01d');
    });
  });

  group('группы погоды', () {
    test('коды группируются как в OpenWeather', () {
      expect(WmoCodes.group(0), 'Clear');
      expect(WmoCodes.group(2), 'Clouds');
      expect(WmoCodes.group(3), 'Clouds');
      expect(WmoCodes.group(45), 'Mist');
      expect(WmoCodes.group(55), 'Drizzle');
      expect(WmoCodes.group(65), 'Rain');
      expect(WmoCodes.group(81), 'Rain');
      expect(WmoCodes.group(73), 'Snow');
      expect(WmoCodes.group(86), 'Snow');
      expect(WmoCodes.group(96), 'Thunderstorm');
    });

    test('неизвестный код считается ясным', () {
      expect(WmoCodes.group(999), 'Clear');
    });
  });

  group('ключи перевода', () {
    test('все ключи есть в обоих языках', () {
      final missing = <String>[];
      for (final entry in WmoCodes.descriptionKeys.entries) {
        final key = entry.value;
        for (final locale in [
          LocaleManager.russianLocale,
          LocaleManager.englishLocale,
        ]) {
          // getText возвращает сам ключ, если перевода нет.
          final text = LocaleManager().getText(key, locale: locale);
          if (text == key) missing.add('$locale: $key (код ${entry.key})');
        }
      }
      expect(missing, isEmpty);
    });

    test('неизвестный код даёт ключ unknown, который переведён', () {
      final key = WmoCodes.descriptionKey(999);
      expect(key, 'unknown');
      expect(LocaleManager().getText(key), isNot(key));
    });
  });
}
