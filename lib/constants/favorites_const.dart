import 'package:flutter/material.dart';

class FavoritesConst {
  FavoritesConst._();

  // ──────────────────────────────
  // ЦВЕТА
  // ──────────────────────────────
  static const Color bgScreen = Color(0xFF080808);
  static const Color bgCard = Color(0x14FFFFFF); // 0.08
  static const Color bgCardSecondary = Color(0x0FFFFFFF); // 0.06
  static const Color bgSearchBar = Color(0x0FFFFFFF); // 0.06
  static const Color bgHeaderButton = Color(0x0FFFFFFF); // 0.06
  static const Color bgIconBox = Color(0x0DFFFFFF); // 0.05
  static const Color bgIconBoxWhite = Color(0x0AFFFFFF); // 0.04
  static const Color bgBadge = Color(0x26FFFFFF); // 0.15
  static const Color bgPriorityBadge = Color(0x26EF4444); // 0.15

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x66FFFFFF); // 0.4
  static const Color textTertiary = Color(0x59FFFFFF); // 0.35
  static const Color textVeryDim = Color(0x33FFFFFF); // 0.2
  static const Color textVeryDim2 = Color(0x4DFFFFFF); // 0.3
  static const Color textSearchHint = Color(0x4DFFFFFF); // 0.3
  static const Color textSearchIcon = Color(0x66FFFFFF); // 0.4
  static const Color textCursor = Color(0x99FFFFFF); // 0.6
  static const Color textSearchCursor = Color(0x99FFFFFF); // 0.6

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentGold = Color(0xFFFFD700);

  // ──────────────────────────────
  // РАДИУСЫ
  // ──────────────────────────────
  static const double radiusCard = 16.0;
  static const double radiusIconBox = 14.0;
  static const double radiusSearchBar = 16.0;
  static const double radiusHeaderButton = 14.0;
  static const double radiusBadge = 8.0;
  static const double radiusPriorityBadge = 6.0;
  static const double radiusActionButton = 12.0;

  // ──────────────────────────────
  // ОТСТУПЫ
  // ──────────────────────────────
  static const EdgeInsets padHeader = EdgeInsets.fromLTRB(8, 8, 16, 4);
  static const EdgeInsets padSearchBar = EdgeInsets.fromLTRB(16, 8, 16, 12);
  static const EdgeInsets padMainList = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets padCardContent = EdgeInsets.all(14);
  static const EdgeInsets padBadge = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const EdgeInsets padPriorityBadge = EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  // ──────────────────────────────
  // ТИПОГРАФИКА
  // ──────────────────────────────
  static const TextStyle tsHeaderTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary);
  static const TextStyle tsSectionHeader = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 1.2);
  static const TextStyle tsLocationName = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary);
  static const TextStyle tsLocationCountry = TextStyle(fontSize: 12, color: textSecondary);
  static const TextStyle tsBadgeText = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentBlue);
  static const TextStyle tsPriorityBadgeText = TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: accentRed);
  static const TextStyle tsEmptyTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textTertiary);
  static const TextStyle tsEmptySubtitle = TextStyle(fontSize: 13, color: textVeryDim);
  static const TextStyle tsSearchEmpty = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textSecondary);
  static const TextStyle tsSearchInput = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary);
  static const TextStyle tsSearchHint = TextStyle(fontSize: 15, color: textSearchHint);

  // ──────────────────────────────
  // РАЗМЕРЫ
  // ──────────────────────────────
  static const double headerButtonSize = 44.0;
  static const double headerIconSize = 20.0;
  static const double headerCloseIconSize = 22.0;
  static const double searchBarHeight = 48.0;
  static const double searchIconSize = 22.0;
  static const double cardIconBoxSize = 44.0;
  static const double cardIconSize = 24.0;
  static const double actionButtonSize = 40.0;
  static const double actionIconSize = 24.0;
  static const double emptyIconSize = 56.0;
  static const double emptySearchIconSize = 48.0;

  // ──────────────────────────────
  // BLUR
  // ──────────────────────────────
  static const double blurCard = 15.0;
  static const double blurSearchBar = 10.0;

  // ──────────────────────────────
  // АНИМАЦИИ
  // ──────────────────────────────
  static const Duration durCardFade = Duration(milliseconds: 300);
  static const Duration durCardFadeCurrent = Duration(milliseconds: 400);
}

// ──────────────────────────────
// ПЕРЕИСПОЛЬЗУЕМЫЕ БОРДЕРЫ
// ──────────────────────────────
Border favoritesDefaultBorder() => Border.all(color: Colors.white.withValues(alpha: 0.08));
Border favoritesDefaultBorder01() => Border.all(color: Colors.white.withValues(alpha: 0.1));
Border favoritesFocusedBorder() => Border.all(color: Colors.white.withValues(alpha: 0.2));
Border favoritesBlueBorder() => Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25));
Border favoritesRedBorder() => Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3));