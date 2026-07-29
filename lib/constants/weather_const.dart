import 'package:flutter/material.dart';

class WeatherConst {
  WeatherConst._();

   
  // ЦВЕТА
   
  static const Color bgScreen = Color(0xFF080808);
  static const Color bgCard = Color(0x14FFFFFF); // 0.08 opacity white
  static const Color bgCardLighter = Color(0x1AFFFFFF); // 0.10 opacity
  static const Color bgDetailCard = Color(0x0FFFFFFF); // 0.06 opacity
  static const Color bgForecastItem = Color(0x0AFFFFFF); // 0.04 opacity
  static const Color bgSunItem = Color(0x0AFFFFFF); // 0.04 opacity
  static const Color bgTimeBadge = Color(0x14FFFFFF); // 0.08 accent overlay

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);

  static const Color accentSunYellow = Color(0xFFFFD700);
  static const Color accentSunOrange = Color(0xFFFF8C00);
  static const Color accentSunsetRed = Color(0xFFFF6B6B);
  static const Color accentAir = Color(0xFF4ECDC4);

   
  // РАДИУСЫ
   
  static const double radiusCard = 24.0;
  static const double radiusGlassCard = 16.0;
  static const double radiusForecastItem = 10.0;
  static const double radiusDetailCard = 18.0;
  static const double radiusSunItem = 14.0;
  static const double radiusTimeBadge = 8.0;
  static const double radiusTipCard = 16.0;
  static const double radiusTipIcon = 10.0;
  static const double radiusWeatherIconBg = 20.0;

   
  // ОТСТУПЫ (наиболее повторяемые)
   
  static const EdgeInsets padScreen = EdgeInsets.fromLTRB(12, 16, 12, 30);
  static const EdgeInsets padCardContent = EdgeInsets.all(20);
  static const EdgeInsets padGlassCardContent = EdgeInsets.all(14);
  static const EdgeInsets padTipCard = EdgeInsets.all(12);
  static const EdgeInsets padDetailCard = EdgeInsets.all(16);
  static const EdgeInsets padSunItem = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets padForecastItem = EdgeInsets.symmetric(vertical: 8, horizontal: 12);
  static const EdgeInsets padTimeBadge = EdgeInsets.symmetric(horizontal: 6, vertical: 3);

   
  // ТИПОГРАФИКА
   
  static const TextStyle tsCityName = TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textPrimary);
  static const TextStyle tsDateLabel = TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600);
  static const TextStyle tsHeroTemp = TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: textPrimary, shadows: [Shadow(blurRadius: 12, color: Colors.black26)]);
  static const TextStyle tsDescription = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle tsDetailValue = TextStyle(fontSize: 26, fontWeight: FontWeight.w900);
  static const TextStyle tsDetailLabel = TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w800);
  static const TextStyle tsGlassCardTitle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary);
  static const TextStyle tsSunTime = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary);
  static const TextStyle tsSunLabel = TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500);
  static const TextStyle tsAirQualityValue = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)]);
  static const TextStyle tsAirQualityLabel = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle tsTipTitle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const TextStyle tsTipMessage = TextStyle(fontSize: 11, color: textSecondary);
  static const TextStyle tsTipTime = TextStyle(fontSize: 9, fontWeight: FontWeight.w500);
  static const TextStyle tsForecastTime = TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500);
  static const TextStyle tsForecastDesc = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle tsForecastTemp = TextStyle(fontSize: 16, color: textPrimary, fontWeight: FontWeight.bold);

   
  // BLUR
   
  static const double blurMain = 20.0;
  static const double blurGlass = 15.0;

   
  // АНИМАЦИИ
   
  static const Duration durFadeIn = Duration(milliseconds: 400);
  static const Duration durHeaderAnim = Duration(milliseconds: 300);
  static const Duration durScrollAnim = Duration(milliseconds: 500);
  static const Duration durPulse = Duration(seconds: 2);

   
  // ПРОЧЕЕ
   
  static const double scrollThreshold = 250.0;
  static const List<String> daysOfWeekFull = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
  static const double forecastIconSize = 24.0;
  static const double mainWeatherIconSize = 40.0;
  static const double tipIconSize = 22.0;
  static const double sunDotSize = 40.0;
  static const double tipDotSize = 40.0;
}