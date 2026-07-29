import 'package:flutter/material.dart';

class SettingsConst {
  SettingsConst._();

  // ЦВЕТА
  static const Color bgScreen = Color(0xFF080808);
  static const Color bgCard = Color(0x14FFFFFF); // 0.08
  static const Color bgButton = Color(0x0FFFFFFF); // 0.06
  static const Color bgButtonDisabled = Color(0x08FFFFFF); // 0.03
  static const Color bgIconBox = Color(0x0DFFFFFF); // 0.05
  static const Color bgMenuButton = Color(0x0AFFFFFF); // 0.04

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textDim = Color(0x4DFFFFFF); // 0.3
  static const Color textVeryDim = Color(0x66FFFFFF); // 0.4
  static const Color textMedium = Color(0xB3FFFFFF); // 0.7

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);

  // РАДИУСЫ
  static const double radiusCard = 20.0;
  static const double radiusIconBox = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusHeaderButton = 14.0;

  // ОТСТУПЫ
  static const EdgeInsets padScreen = EdgeInsets.fromLTRB(16, 8, 16, 30);
  static const EdgeInsets padHeader = EdgeInsets.fromLTRB(8, 8, 16, 8);
  static const EdgeInsets padCardContent = EdgeInsets.all(18);
  static const EdgeInsets padMenuButton = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const EdgeInsets padButton = EdgeInsets.symmetric(vertical: 14);

  // ТИПОГРАФИКА
  static const TextStyle tsHeaderTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary);
  static const TextStyle tsSectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary);
  static const TextStyle tsSectionSubtitle = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle tsButtonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle tsMenuButtonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle tsCopyright = TextStyle(fontSize: 12, color: textDim);

  // РАЗМЕРЫ
  static const double headerButtonSize = 44.0;
  static const double headerIconSize = 20.0;
  static const double sectionIconBoxSize = 40.0;
  static const double sectionIconSize = 22.0;
  static const double menuIconSize = 20.0;
  static const double menuArrowSize = 14.0;

  // BLUR
  static const double blurGlass = 15.0;

  // АНИМАЦИИ
  static const Duration durSectionFade = Duration(milliseconds: 400);
  static const Duration durSectionFade2 = Duration(milliseconds: 500);
  static const Duration durSectionFade3 = Duration(milliseconds: 600);

  // ПРОЧЕЕ
  /* // ← ЗАКОММЕНТИРОВАНО (связано с Telegram)
  static const String telegramUsername = 'durovfm';
  // КОНЕЦ */
  static const String copyrightText = '© 2026 Weather Cloud';
  static const String appVersion = 'Версия 1.0.0r';

  // ПЕРЕИСПОЛЬЗУЕМЫЕ БОРДЕРЫ
  static Border get defaultBorder => Border.all(color: Colors.white.withValues(alpha: 0.1));
  static Border get subtleBorder => Border.all(color: Colors.white.withValues(alpha: 0.05));
  static Border get subtleBorder06 => Border.all(color: Colors.white.withValues(alpha: 0.06));
  static BorderSide get defaultBorderSide => BorderSide(color: Colors.white.withValues(alpha: 0.1));

  // CHANGELOG
static const String changelogCurrentVersion = '0.9.0 Beta';

static const String changelogText = ''
    // 0.9.0 Beta
    '0.9.0 Beta\n'
    'Первое публичное бета-тестирование.\n\n'
    '- Навигация: теперь панель управления скрывается при прокрутке вниз и плавно возвращается при прокрутке вверх.\n\n'
    '- Удалена иконка мусора с кнопки "Очистить данные".\n\n'
    '- Исправлен огромный отступ снизу на главном экране.\n\n'
    '- Блок "Помощь и обратная связь" временно отключен.\n\n'
    '- Блок "Графики" закомментирован для подготовки к обновлению.\n\n'
    '- Оптимизировано поведение компактного хедера при скролле.\n\n'
    '- Улучшена общая стабильность и плавность анимаций.\n\n'

    // 0.8.7-патч
    '0.8.7-patch\n'
    'Стабилизационный патч.\n\n'
    '- Добавлен шанс дождя в карточки "Почасовой прогноз" и "Пятидневный прогноз"\n\n'
    '- Улучшено поведение страницы "Activity": обновление данных стало стабильнее и предсказуемее.\n\n'
    '- Исправлена проблема с бесконечным индикатором загрузки при выходе со страницы.\n\n'
    '- Улучшена синхронизация локального кэша и состояния интерфейса.\n\n'
    '- Оптимизирован процесс фонового обновления данных (меньше лишних перезагрузок).\n\n'
    '- Повышена общая стабильность работы страницы активности.\n\n'

    // 0.8.6b
    '0.8.6b\n'
    'Продолжаются улучшения.\n\n'
    '- На странице "Другое" (ранее "Активности") добавлены дополнительные '
    'показатели с Open-Meteo: УФ-индекс, точка росы, видимость, '
    'вероятность осадков и солнечная радиация.\n\n'
    '- Убран эффект свечения при прокрутке в конце списка.\n\n'
    '- Добавлен экран "Что нового?" в настройках приложения.\n\n'
    // 0.8.5b
    '0.8.5b\n'
    'Первое публичное тестирование.\n\n'
    '- Переработана структура получения данных от API. '
    'Теперь есть OWM и OM. Если OWM не отвечает, '
    'в ту же секунду придут данные от OM. '
    'За счёт переработки структуры и добавления нового источника данных '
    'парсинг данных стал быстрее.\n\n'
    '- Благодаря OM исчезла проблема с рассветом/закатом. '
    'Теперь отображение времени в этой секции правильное в любом регионе.\n\n'
    '- Секция с советом перемещена чуть выше.\n\n'
    '- Микро изменение: текст в ветре теперь отображается как '
    '"Ветер: Северный; Северо-Западный" '
    '(ранее было "Ветер С; СЗ").\n\n'
    '- Переработана страница "Активности" — теперь она называется "Другое". '
    'Подготовлено место под новые секции.\n\n'
    '- Оптимизировано: некоторые элементы кода вынесены в папку utils '
    'в файл weather_utils.dart.\n\n'
    '- Подготовлена площадка под локализацию.\n\n'
    '- Анимации стали чуть плавнее.';
}