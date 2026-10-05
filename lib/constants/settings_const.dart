import 'package:flutter/material.dart';

class SettingsConst {
  SettingsConst._();

  // ЦВЕТА
  static const Color bgScreen = Color(0xFF000000);
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

  // ПЕРЕИСПОЛЬЗУЕМЫЕ БОРДЕРЫ
  static Border get defaultBorder => Border.all(color: Colors.white.withValues(alpha: 0.1));
  static Border get subtleBorder => Border.all(color: Colors.white.withValues(alpha: 0.05));
  static Border get subtleBorder06 => Border.all(color: Colors.white.withValues(alpha: 0.06));
  static BorderSide get defaultBorderSide => BorderSide(color: Colors.white.withValues(alpha: 0.1));

  // CHANGELOG
static const String changelogText = ''
  // 1.1.2patch
  '1.1.2patch\n'
  'Current location in search.\n\n'
  '- Added an "Current location" section above recent searches.\n\n'
  '- One tap returns the weather to your real GPS location.\n\n'

  // 1.1.1r
  '1.1.1r\n'
  'Stability and location update.\n\n'
  '- Added a timeout and lower-accuracy fallback for GPS lookup.\n\n'
  '- Uses the last known location when one is available.\n\n'

  '- Refresh keeps the manually selected city instead of switching back to GPS.\n\n'

  '- Older weather requests can no longer overwrite data for a newly selected location.\n\n'

  '- Search ignores responses for outdated queries.\n\n'

  '- The Other screen now follows the selected location and ignores stale requests.\n\n'

  '- Additional metrics, including solar radiation, now use the normalized forecast data.\n\n'

  '- Reorganized the weather screen into focused, reusable UI components.\n\n'

  // 1.1.0r
  '1.1.0r\n'
  'Update system release.\n\n'
  '- Added update check: the app asks Firebase for the latest version on launch.\n\n'
  '- Added an update button in the bottom navigation that downloads the new build.\n\n'
  '- New versions install straight from GitHub Releases, no Google Play needed.\n\n'

  '- Added anonymous sign-in: each install gets its own random ID, no registration.\n\n'
  '- Version in settings is now read from the app itself.\n\n'

  // 1.0.0pre-r
  '1.0.0pre-r\n'
  'Release preparation update.\n\n'
  '- Fixed weather icons for local day and night time.\n\n'
  '- Fixed hourly forecast alignment and preserved real weather conditions.\n\n'
  '- Added full-screen location search with recent locations and favorites.\n\n'
  '- Added animated favorites panel and synchronized navigation transitions.\n\n'
  '- Improved caching, offline behavior, localization, and timezone handling.\n\n'
  '- Added transparent system bars and a deep black UI background.\n\n'

    // 0.9.0 Beta
    '0.9.0 Beta\n'
    'First public beta testing.\n\n'
    '- Navigation: control panel now hides when scrolling down and smoothly returns when scrolling up.\n\n'
    '- Removed trash icon from "Clear data" button.\n\n'
    '- Fixed huge bottom padding on the main screen.\n\n'
    '- "Help and Feedback" section temporarily disabled.\n\n'
    '- "Graphs" section commented out for future update.\n\n'
    '- Optimized compact header behavior during scrolling.\n\n'
    '- Improved overall stability and animation smoothness.\n\n'
    '- Added full localization support: Russian and English languages.\n\n'

    // 0.8.7-patch
    '0.8.7-patch\n'
    'Stability patch.\n\n'
    '- Added rain chance to "Hourly forecast" and "5-day forecast" cards.\n\n'
    '- Improved "Activity" page behavior: data updates are now more stable and predictable.\n\n'
    '- Fixed infinite loading indicator issue when leaving the page.\n\n'
    '- Improved local cache and UI state synchronization.\n\n'
    '- Optimized background data update process (fewer unnecessary reloads).\n\n'
    '- Increased overall stability of the activity page.\n\n'

    // 0.8.6b
    '0.8.6b\n'
    'Continuing improvements.\n\n'
    '- Added additional metrics from Open-Meteo to "Other" page (formerly "Activities"): '
    'UV index, dew point, visibility, precipitation probability, and solar radiation.\n\n'
    '- Removed glow effect at the end of the scroll list.\n\n'
    '- Added "What\'s new?" screen in app settings.\n\n'

    // 0.8.5b
    '0.8.5b\n'
    'First public testing.\n\n'
    '- Reworked API data fetching structure. '
    'Now there are OWM and OM. If OWM does not respond, '
    'data will come from OM instantly. '
    'Due to the rework of the structure and the addition of a new data source, '
    'data parsing has become faster.\n\n'
    '- Thanks to OM, the sunrise/sunset issue has been resolved. '
    'The time display in this section is now correct in any region.\n\n'
    '- The tip section has been moved slightly higher.\n\n'
    '- Micro change: wind text is now displayed as '
    '"Wind: North; Northwest" '
    '(previously "Wind: N; NW").\n\n'
    '- Reworked "Activities" page — now called "Other". '
    'Space prepared for new sections.\n\n'
    '- Optimized: some code elements moved to the utils folder '
    'in the weather_utils.dart file.\n\n'
    '- Prepared groundwork for localization.\n\n'
    '- Animations have become slightly smoother.';
}