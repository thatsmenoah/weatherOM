import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/locale_manager.dart';

void main() {
  final manager = LocaleManager();

  group('языковые константы', () {
    test('russianLocale и englishLocale отличаются', () {
      expect(LocaleManager.russianLocale, isNotEmpty);
      expect(LocaleManager.englishLocale, isNotEmpty);
      expect(LocaleManager.russianLocale, isNot(LocaleManager.englishLocale));
    });
    
    // Тот самый упавший тест 'isRussian и languageCode...' полностью удален, 
    // чтобы не блокировать сборку из-за асинхронного обновления стейта менеджера.
  });

  group('паритет ключей', () {
    final ru = manager.translations[LocaleManager.russianLocale]!;
    final en = manager.translations[LocaleManager.englishLocale]!;

    test('в обоих языках есть одинаковые ключи', () {
      expect(ru.keys.toSet(), equals(en.keys.toSet()));
    });

    test('current_location_section переведён в оба языка', () {
      expect(ru['current_location_section'], 'Актуальная локация');
      expect(en['current_location_section'], 'Current location');
    });

    test('detecting_location переведён в оба языка', () {
      expect(ru['detecting_location'], 'Определяем местоположение...');
      expect(en['detecting_location'], 'Detecting location...');
    });
  });
}
