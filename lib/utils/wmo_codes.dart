/// Единая таблица кодов погоды WMO (Open-Meteo).
///
/// Раньше одна и та же таблица была продублирована в сервисе и в виджете
/// прогноза, из-за чего иконки могли разъезжаться. Теперь маппинг живёт здесь,
/// а потребители только читают его.
class WmoCodes {
  WmoCodes._();

  /// Код -> ключ перевода описания в [LocaleManager].
  static const Map<int, String> descriptionKeys = {
    0: 'clear_sky',
    1: 'mostly_clear',
    2: 'partly_cloudy',
    3: 'overcast',
    45: 'fog',
    48: 'freezing_fog',
    51: 'light_drizzle',
    53: 'moderate_drizzle',
    55: 'heavy_drizzle',
    56: 'light_freezing_drizzle',
    57: 'heavy_freezing_drizzle',
    61: 'light_rain',
    63: 'moderate_rain',
    65: 'heavy_rain',
    66: 'light_freezing_rain',
    67: 'heavy_freezing_rain',
    71: 'light_snow',
    73: 'moderate_snow',
    75: 'heavy_snow',
    77: 'snow_grains',
    80: 'light_shower',
    81: 'moderate_shower',
    82: 'heavy_shower',
    85: 'light_snow_shower',
    86: 'heavy_snow_shower',
    95: 'thunderstorm',
    96: 'thunderstorm_hail',
    99: 'heavy_thunderstorm',
  };

  /// Код -> короткое имя группы погоды (как в OpenWeather).
  static String group(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2 || code == 3) return 'Clouds';
    if (code >= 45 && code <= 48) return 'Mist';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain';
    if (code >= 85 && code <= 86) return 'Snow';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clear';
  }

  /// Код -> код иконки (01d, 10n и т.д.).
  static String icon(int code, {bool isDay = true}) {
    final suffix = isDay ? 'd' : 'n';
    if (code == 0) return '01$suffix';
    if (code == 1) return '02$suffix';
    if (code == 2) return '03$suffix';
    if (code == 3) return '04$suffix';
    if (code >= 45 && code <= 48) return '50$suffix';
    if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67)) {
      return '10$suffix';
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return '13$suffix';
    }
    if (code >= 80 && code <= 82) return '09$suffix';
    if (code >= 95 && code <= 99) return '11$suffix';
    return '01$suffix';
  }

  /// Ключ перевода описания; для неизвестного кода — 'unknown'.
  static String descriptionKey(int code) => descriptionKeys[code] ?? 'unknown';
}
