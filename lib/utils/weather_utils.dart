import 'package:flutter/material.dart';
import '../core/locale_manager.dart';

class WeatherUtils {
  // ==================== ФОРМАТИРОВАНИЕ ДАТЫ ====================

  static String formatDate(DateTime date, LocaleManager localeManager) {
    final months = [
      localeManager.getText('january'),
      localeManager.getText('february'),
      localeManager.getText('march'),
      localeManager.getText('april'),
      localeManager.getText('may'),
      localeManager.getText('june'),
      localeManager.getText('july'),
      localeManager.getText('august'),
      localeManager.getText('september'),
      localeManager.getText('october'),
      localeManager.getText('november'),
      localeManager.getText('december'),
    ];
    final weekdays = [
      localeManager.getText('monday'),
      localeManager.getText('tuesday'),
      localeManager.getText('wednesday'),
      localeManager.getText('thursday'),
      localeManager.getText('friday'),
      localeManager.getText('saturday'),
      localeManager.getText('sunday'),
    ];
    return '${date.day} ${months[date.month - 1]}, ${weekdays[date.weekday - 1]}';
  }

  // ==================== НАПРАВЛЕНИЕ ВЕТРА ====================

  static String getWindDirection(int degrees, LocaleManager localeManager) {
    List<String> directions = [
      localeManager.getText('n'),
      localeManager.getText('ne'),
      localeManager.getText('e'),
      localeManager.getText('se'),
      localeManager.getText('s'),
      localeManager.getText('sw'),
      localeManager.getText('w'),
      localeManager.getText('nw'),
    ];
    int index = ((degrees + 22) ~/ 45) % 8;
    return directions[index];
  }

  // ==================== СТРЕЛКА НАПРАВЛЕНИЯ ВЕТРА ====================

  static Widget getWindArrow(double degrees, {double size = 16, Color? color}) {
    final rotation = (degrees - 180) * 3.14159 / 180;
    return Transform.rotate(
      angle: rotation,
      child: Icon(
        Icons.navigation,
        size: size,
        color: color ?? Colors.grey.withValues(alpha: 0.8),
      ),
    );
  }

  static double getWindArrowRotation(double degrees) {
    return (degrees - 180) * 3.14159 / 180;
  }

  static IconData getWindArrowIcon(double degrees) {
    return Icons.navigation;
  }

  static String getWindArrowSymbol(double degrees) {
    degrees = degrees % 360;
    if (degrees < 0) degrees += 360;
    if (degrees >= 337.5 || degrees < 22.5) return '↑';
    if (degrees >= 22.5 && degrees < 67.5) return '↗';
    if (degrees >= 67.5 && degrees < 112.5) return '→';
    if (degrees >= 112.5 && degrees < 157.5) return '↘';
    if (degrees >= 157.5 && degrees < 202.5) return '↓';
    if (degrees >= 202.5 && degrees < 247.5) return '↙';
    if (degrees >= 247.5 && degrees < 292.5) return '←';
    if (degrees >= 292.5 && degrees < 337.5) return '↖';
    return '→';
  }

  static String getWindDirectionWithArrow(int degrees, LocaleManager localeManager) {
    final direction = getWindDirection(degrees, localeManager);
    final arrow = getWindArrowSymbol(degrees.toDouble());
    return '$direction $arrow';
  }

  // ==================== КАЧЕСТВО ВОЗДУХА ====================

  static String getAirQualityText(int? aqi, LocaleManager localeManager) {
    if (aqi == null) return localeManager.getText('no_data');
    switch (aqi) {
      case 1:
        return localeManager.getText('air_excellent');
      case 2:
        return localeManager.getText('air_good');
      case 3:
        return localeManager.getText('air_moderate');
      case 4:
        return localeManager.getText('air_poor');
      case 5:
        return localeManager.getText('air_very_poor');
      default:
        return localeManager.getText('no_data');
    }
  }

  static Color getAirQualityColor(int? aqi) {
    return Colors.white;
  }

  // ==================== КОРОТКОЕ ОПИСАНИЕ ПОГОДЫ ====================

  static String getShortWeatherDescription(String iconCode, LocaleManager localeManager) {
    switch (iconCode) {
      case '01d':
      case '01n':
        return localeManager.getText('desc_clear');
      case '02d':
      case '02n':
      case '03d':
      case '03n':
        return localeManager.getText('desc_cloudy');
      case '04d':
      case '04n':
        return localeManager.getText('desc_overcast');
      case '09d':
      case '09n':
      case '10d':
      case '10n':
        return localeManager.getText('desc_rain');
      case '11d':
      case '11n':
        return localeManager.getText('desc_thunderstorm');
      case '13d':
      case '13n':
        return localeManager.getText('desc_snow');
      case '50d':
      case '50n':
        return localeManager.getText('desc_fog');
      default:
        return localeManager.getText('desc_clear');
    }
  }

  // ==================== ИКОНКА ПОГОДЫ ====================

  static IconData getWeatherIcon(String iconCode) {
    switch (iconCode) {
      case '01d':
        return Icons.wb_sunny;
      case '01n':
        return Icons.nightlight_round;
      case '02d':
        return Icons.wb_cloudy;
      case '02n':
        return Icons.nightlight_round;
      case '03d':
      case '03n':
      case '04d':
      case '04n':
        return Icons.cloud;
      case '09d':
      case '09n':
        return Icons.grain;
      case '10d':
      case '10n':
        return Icons.beach_access;
      case '11d':
      case '11n':
        return Icons.flash_on;
      case '13d':
      case '13n':
        return Icons.ac_unit;
      case '50d':
      case '50n':
        return Icons.foggy;
      default:
        return Icons.wb_sunny;
    }
  }

  // ==================== КОНВЕРТАЦИЯ ДАВЛЕНИЯ ====================

  static double convertPressureToMmhg(double pressureHpa) {
    return pressureHpa * 0.750062;
  }

  // ==================== UI-МЕТОДЫ ====================

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String formatForecastTime(DateTime time, bool isNow, LocaleManager localeManager) {
    return isNow ? localeManager.getText('now') : '${time.hour}:00';
  }

  static String getWeekday(DateTime date, LocaleManager localeManager) {
    final weekdays = [
      localeManager.getText('sunday'),
      localeManager.getText('monday'),
      localeManager.getText('tuesday'),
      localeManager.getText('wednesday'),
      localeManager.getText('thursday'),
      localeManager.getText('friday'),
      localeManager.getText('saturday'),
    ];
    return weekdays[date.weekday % 7];
  }

  static String formatTemp(num temp) => '${temp.round()}°';

  static String formatTempWithFeelsLike(num temp, num feelsLike, LocaleManager localeManager) {
    return '${temp.round()}° (${localeManager.getText('feels_like')} ${feelsLike.round()}°)';
  }

  static bool isTipImportant(Map<String, dynamic> tip) {
    return tip['type'] == 'rain' || tip['type'] == 'snow';
  }

  static String getDailyForecastLabel(int index, LocaleManager localeManager) {
    switch (index) {
      case 0:
        return localeManager.getText('today');
      case 1:
        return localeManager.getText('tomorrow');
      default:
        return '';
    }
  }

  // ============ ОБНОВЛЁННЫЕ МЕТОДЫ С ПЕРЕВОДОМ ЕДИНИЦ ============

  static String formatWindSpeed(double speedMs, LocaleManager localeManager) {
    return '${speedMs.toStringAsFixed(1)} ${localeManager.getText('ms')}';
  }

  static String formatHumidity(double humidity) {
    return '${humidity.round()}%';
  }

  static String formatPressure(double pressureHpa, LocaleManager localeManager) {
    return '${convertPressureToMmhg(pressureHpa).round()} ${localeManager.getText('mm')}';
  }

  static String extractHourFromDateTime(String dtTxt) {
    final time = DateTime.parse(dtTxt);
    return '${time.hour}:00';
  }

  // ==================== МЕТОДЫ ДЛЯ АКТИВНОСТЕЙ ====================

  static double calculateActivityScore(
    String activity,
    Map<String, dynamic>? weatherData,
    Map<String, dynamic>? airQualityData,
  ) {
    if (weatherData == null) return 5.0;

    final temp = weatherData['main']['temp'].toDouble();
    final windSpeed = (weatherData['wind']['speed'] * 3.6).toDouble();
    final precipitation = _getPrecipitation(weatherData);
    final clouds = weatherData['clouds']['all'].toDouble();

    double weatherScore = _calculateWeatherScore(temp, windSpeed, precipitation);
    final airScore = calculateAirQualityScore(airQualityData) ?? 5.0;

    double finalScore;
    switch (activity) {
      case 'running':
        finalScore = weatherScore * 0.6 + airScore * 0.4;
        if (temp >= 15 && temp <= 20) finalScore += 0.5;
        if (windSpeed > 4) finalScore -= 0.5;
        break;
      case 'cycling':
        finalScore = weatherScore * 0.55 + airScore * 0.45;
        if (windSpeed > 5.5) {
          finalScore -= 1.0;
        } else if (windSpeed > 3.3) {
          finalScore -= 0.5;
        }
        break;
      case 'walking':
        finalScore = weatherScore * 0.7 + airScore * 0.3;
        if (clouds <= 30 && temp >= 10 && temp <= 25) finalScore += 0.5;
        if (windSpeed < 1.4) finalScore += 0.5;
        break;
      case 'photography':
        finalScore = weatherScore * 0.85 + airScore * 0.15;
        if (clouds <= 20) {
          finalScore += 1.0;
        } else if (clouds >= 80) {
          finalScore -= 1.5;
        }
        break;
      default:
        finalScore = weatherScore;
    }
    return finalScore.clamp(0.0, 10.0);
  }

  static double _getPrecipitation(Map<String, dynamic> weatherData) {
    if (weatherData.containsKey('rain')) {
      final rain = weatherData['rain'];
      if (rain != null) {
        return (rain['1h'] ?? rain['3h'] ?? 0).toDouble();
      }
    }
    if (weatherData.containsKey('snow')) {
      final snow = weatherData['snow'];
      if (snow != null) {
        return (snow['1h'] ?? snow['3h'] ?? 0).toDouble();
      }
    }
    return 0.0;
  }

  static double _calculateWeatherScore(double temp, double windSpeed, double precipitation) {
    double score = 5.0;

    if (temp >= 18 && temp <= 24) {
      score = 10.0;
    } else if (temp >= 15 && temp < 18) {
      score = 9.0;
    } else if (temp >= 10 && temp < 15) {
      score = 7.0;
    } else if (temp > 24 && temp <= 28) {
      score = 8.0;
    } else if (temp > 28 && temp <= 32) {
      score = 6.0;
    } else if (temp >= 5 && temp < 10) {
      score = 5.0;
    } else if (temp >= 0 && temp < 5) {
      score = 3.0;
    } else if (temp < 0) {
      score = 1.0;
    } else if (temp > 32) {
      score = 2.0;
    }

    if (windSpeed > 7) {
      score -= 3.0;
    } else if (windSpeed > 4) {
      score -= 2.0;
    } else if (windSpeed > 2.7) {
      score -= 1.0;
    } else if (windSpeed < 0.5) {
      score += 0.5;
    }

    if (precipitation > 5) {
      score -= 4.0;
    } else if (precipitation > 2) {
      score -= 2.5;
    } else if (precipitation > 0.5) {
      score -= 1.0;
    } else if (precipitation > 0) {
      score -= 0.5;
    }

    return score.clamp(0.0, 10.0);
  }

  // 🔥 ИСПРАВЛЕНО: возвращаем null если нет данных
  static double? calculateAirQualityScore(Map<String, dynamic>? airQualityData) {
    if (airQualityData == null || airQualityData['list'] == null) {
      return null;
    }

    final aqi = airQualityData['list'][0]['main']['aqi'];
    if (aqi == null) {
      return null;
    }

    final comp = airQualityData['list'][0]['components'];
    double totalScore = 0.0;
    int count = 0;

    // PM2.5
    if (comp['pm2_5'] != null) {
      final pm25 = comp['pm2_5'].toDouble();
      if (pm25 <= 10) {
        totalScore += 10.0;
      } else if (pm25 <= 25) {
        totalScore += 8.0;
      } else if (pm25 <= 50) {
        totalScore += 5.0;
      } else if (pm25 <= 75) {
        totalScore += 3.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    // PM10
    if (comp['pm10'] != null) {
      final pm10 = comp['pm10'].toDouble();
      if (pm10 <= 20) {
        totalScore += 10.0;
      } else if (pm10 <= 50) {
        totalScore += 7.0;
      } else if (pm10 <= 100) {
        totalScore += 4.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    // CO (µg/m³)
    if (comp['co'] != null) {
      final co = comp['co'].toDouble();
      if (co <= 5000) {
        totalScore += 10.0;
      } else if (co <= 10000) {
        totalScore += 7.0;
      } else if (co <= 20000) {
        totalScore += 4.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    // NO2 (µg/m³)
    if (comp['no2'] != null) {
      final no2 = comp['no2'].toDouble();
      if (no2 <= 20) {
        totalScore += 10.0;
      } else if (no2 <= 40) {
        totalScore += 7.0;
      } else if (no2 <= 80) {
        totalScore += 4.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    // SO2 (µg/m³)
    if (comp['so2'] != null) {
      final so2 = comp['so2'].toDouble();
      if (so2 <= 20) {
        totalScore += 10.0;
      } else if (so2 <= 50) {
        totalScore += 7.0;
      } else if (so2 <= 100) {
        totalScore += 4.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    // O3 (µg/m³)
    if (comp['o3'] != null) {
      final o3 = comp['o3'].toDouble();
      if (o3 <= 30) {
        totalScore += 10.0;
      } else if (o3 <= 60) {
        totalScore += 7.0;
      } else if (o3 <= 100) {
        totalScore += 4.0;
      } else {
        totalScore += 1.0;
      }
      count++;
    }

    if (count == 0) return null;
    return (totalScore / count).clamp(0.0, 10.0);
  }

  static String getAirQualityTextByScore(double? score, LocaleManager localeManager) {
    if (score == null) return localeManager.getText('no_data');
    if (score >= 8.5) return localeManager.getText('air_excellent');
    if (score >= 7.0) return localeManager.getText('air_good');
    if (score >= 5.0) return localeManager.getText('air_moderate');
    if (score >= 3.0) return localeManager.getText('air_poor');
    return localeManager.getText('air_very_poor');
  }

  static Color getAirQualityColorByScore(double? score) {
    return Colors.white;
  }
}