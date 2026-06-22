import 'package:flutter/material.dart';

class SettingsConst {
  SettingsConst._();

  // ──────────────────────────────
  // ЦВЕТА
  // ──────────────────────────────
  static const Color bgScreen = Color(0xFF080808);
  static const Color bgCard = Color(0x14FFFFFF); // 0.08
  static const Color bgButton = Color(0x0FFFFFFF); // 0.06
  static const Color bgButtonDisabled = Color(0x08FFFFFF); // 0.03
  static const Color bgIconBox = Color(0x0DFFFFFF); // 0.05
  static const Color bgInfoBox = Color(0x08FFFFFF); // 0.03
  static const Color bgMenuButton = Color(0x0AFFFFFF); // 0.04

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textDim = Color(0x4DFFFFFF); // 0.3
  static const Color textVeryDim = Color(0x66FFFFFF); // 0.4
  static const Color textMedium = Color(0xB3FFFFFF); // 0.7

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentGreen = Color(0xFF10B981);

  // ──────────────────────────────
  // РАДИУСЫ
  // ──────────────────────────────
  static const double radiusCard = 20.0;
  static const double radiusIconBox = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusInfoBox = 12.0;
  static const double radiusHeaderButton = 14.0;
  static const double radiusProgressBar = 20.0;

  // ──────────────────────────────
  // ОТСТУПЫ
  // ──────────────────────────────
  static const EdgeInsets padScreen = EdgeInsets.fromLTRB(16, 8, 16, 30);
  static const EdgeInsets padHeader = EdgeInsets.fromLTRB(8, 8, 16, 8);
  static const EdgeInsets padCardContent = EdgeInsets.all(18);
  static const EdgeInsets padInfoBox = EdgeInsets.all(12);
  static const EdgeInsets padMenuButton = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const EdgeInsets padButton = EdgeInsets.symmetric(vertical: 14);

  // ──────────────────────────────
  // ТИПОГРАФИКА
  // ──────────────────────────────
  static const TextStyle tsHeaderTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary);
  static const TextStyle tsSectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary);
  static const TextStyle tsSectionSubtitle = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle tsStorageLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMedium);
  static const TextStyle tsStorageValue = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accentBlue);
  static const TextStyle tsFooterHint = TextStyle(fontSize: 10, color: textDim);
  static const TextStyle tsButtonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle tsMenuButtonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle tsInfoItemLabel = TextStyle(fontSize: 10, color: textVeryDim);
  static const TextStyle tsInfoItemValue = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static const TextStyle tsCopyright = TextStyle(fontSize: 12, color: textDim);

  // ──────────────────────────────
  // РАЗМЕРЫ
  // ──────────────────────────────
  static const double headerButtonSize = 44.0;
  static const double headerIconSize = 20.0;
  static const double sectionIconBoxSize = 40.0;
  static const double sectionIconSize = 22.0;
  static const double progressBarHeight = 10.0;
  static const double infoIconSize = 18.0;
  static const double menuIconSize = 20.0;
  static const double menuArrowSize = 14.0;
  static const double dividerWidth = 1.0;
  static const double dividerHeight = 30.0;

  // ──────────────────────────────
  // BLUR
  // ──────────────────────────────
  static const double blurGlass = 15.0;

  // ──────────────────────────────
  // АНИМАЦИИ
  // ──────────────────────────────
  static const Duration durSectionFade = Duration(milliseconds: 400);
  static const Duration durSectionFade2 = Duration(milliseconds: 500);
  static const Duration durSectionFade3 = Duration(milliseconds: 600);

  // ──────────────────────────────
  // ПРОЧЕЕ
  // ──────────────────────────────
  static const String telegramUsername = 'wptf80x';
  static const String copyrightText = '© 2026 Weather App';
  static const String appVersion = 'Версия 3.0.0 BETA!';

  // ──────────────────────────────
  // ПЕРЕИСПОЛЬЗУЕМЫЕ БОРДЕРЫ
  // ──────────────────────────────
  static Border get defaultBorder => Border.all(color: Colors.white.withValues(alpha: 0.1));
  static Border get subtleBorder => Border.all(color: Colors.white.withValues(alpha: 0.05));
  static Border get subtleBorder06 => Border.all(color: Colors.white.withValues(alpha: 0.06));
  static BorderSide get defaultBorderSide => BorderSide(color: Colors.white.withValues(alpha: 0.1));
}