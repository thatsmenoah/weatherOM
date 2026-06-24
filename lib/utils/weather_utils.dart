import 'package:flutter/material.dart';

class WeatherUtils {
  // Форматирование даты
  static String formatDate(DateTime date) {
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    return '${date.day} ${months[date.month - 1]}, ${weekdays[date.weekday - 1]}';
  }

  // Направление ветра
  static String getWindDirection(int degrees) {
    List<String> directions = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
    int index = ((degrees + 22) ~/ 45) % 8;
    return directions[index];
  }

  // Текст качества воздуха (по AQI)
  static String getAirQualityText(int aqi) {
    switch(aqi) {
      case 1: return 'Отличное';
      case 2: return 'Хорошое';
      case 3: return 'Умеренное';
      case 4: return 'Плохое';
      case 5: return 'Очень плохое';
      default: return 'Нет данных на';
    }
  }

  // Цвет качества воздуха (по AQI)
  static Color getAirQualityColor(int aqi) {
    return Colors.white;
  }

  // Короткое описание погоды
  static String getShortWeatherDescription(String iconCode) {
    switch(iconCode) {
      case '01d': return 'Ясно';
      case '01n': return 'Ясно';
      case '02d': return 'Облачно';
      case '02n': return 'Облачно';
      case '03d': return 'Облачно';
      case '03n': return 'Облачно';
      case '04d': return 'Пасмурно';
      case '04n': return 'Пасмурно';
      case '09d': return 'Дождь';
      case '09n': return 'Дождь';
      case '10d': return 'Дождь';
      case '10n': return 'Дождь';
      case '11d': return 'Гроза';
      case '11n': return 'Гроза';
      case '13d': return 'Снег';
      case '13n': return 'Снег';
      case '50d': return 'Туман';
      case '50n': return 'Туман';
      default: return 'Ясно';
    }
  }

  // Иконка погоды
  static IconData getWeatherIcon(String iconCode) {
    switch(iconCode) {
      case '01d': return Icons.wb_sunny;
      case '01n': return Icons.nightlight_round;
      case '02d': return Icons.wb_cloudy;
      case '02n': return Icons.nightlight_round;
      case '03d': return Icons.cloud;
      case '03n': return Icons.cloud;
      case '04d': return Icons.cloud;
      case '04n': return Icons.cloud;
      case '09d': return Icons.grain;
      case '09n': return Icons.grain;
      case '10d': return Icons.beach_access;
      case '10n': return Icons.beach_access;
      case '11d': return Icons.flash_on;
      case '11n': return Icons.flash_on;
      case '13d': return Icons.ac_unit;
      case '13n': return Icons.ac_unit;
      case '50d': return Icons.foggy;
      case '50n': return Icons.foggy;
      default: return Icons.wb_sunny;
    }
  }

  // Конвертация давления из гПа в мм рт. ст.
  static double convertPressureToMmhg(double pressureHpa) {
    return pressureHpa * 0.750062;
  }

  // ========== МЕТОДЫ ДЛЯ АКТИВНОСТЕЙ ==========

  // Расчет оценки для активности
  static double calculateActivityScore(
    String activity,
    Map<String, dynamic>? weatherData,
    Map<String, dynamic>? airQualityData,
  ) {
    if (weatherData == null) return 5.0;
    
    final temp = weatherData['main']['temp'].toDouble();
    final windSpeed = (weatherData['wind']['speed'] * 3.6).toDouble(); // км/ч
    final precipitation = _getPrecipitation(weatherData);
    final clouds = weatherData['clouds']['all'].toDouble();
    
    // Базовая погодная оценка (0-10)
    double weatherScore = _calculateWeatherScore(temp, windSpeed, precipitation);
    
    // Оценка качества воздуха (0-10)
    final airScore = calculateAirQualityScore(airQualityData);
    
    // Итоговая оценка с весами для разных активностей
    double finalScore;
    switch(activity) {
      case 'running':
        finalScore = weatherScore * 0.6 + airScore * 0.4;
        if (temp >= 15 && temp <= 20) finalScore += 0.5;
        if (windSpeed > 15) finalScore -= 0.5;
        break;
      case 'cycling':
        finalScore = weatherScore * 0.55 + airScore * 0.45;
        if (windSpeed > 20) {
          finalScore -= 1.0;
        } else if (windSpeed > 12) {
          finalScore -= 0.5;
        }
        break;
      case 'walking':
        finalScore = weatherScore * 0.7 + airScore * 0.3;
        if (clouds <= 30 && temp >= 10 && temp <= 25) finalScore += 0.5;
        if (windSpeed < 5) finalScore += 0.5;
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

  // Получение количества осадков
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

  // Расчет погодной оценки
  static double _calculateWeatherScore(double temp, double windSpeed, double precipitation) {
    double score = 5.0;
    
    // Оценка температуры
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
    
    // Штраф за ветер
    if (windSpeed > 25) {
      score -= 3.0;
    } else if (windSpeed > 15) {
      score -= 2.0;
    } else if (windSpeed > 10) {
      score -= 1.0;
    } else if (windSpeed < 2) {
      score += 0.5;
    }
    
    // Штраф за осадки
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

  // Расчет оценки качества воздуха
  static double calculateAirQualityScore(Map<String, dynamic>? airQualityData) {
    if (airQualityData == null || airQualityData['list'] == null) {
      return 7.0;
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
    
    return count > 0 ? totalScore / count : 7.0;
  }

  // Текст качества воздуха по оценке
  static String getAirQualityTextByScore(double score) {
    if (score >= 8.5) return 'Отличное качество';
    if (score >= 7.0) return 'Хорошее качество';
    if (score >= 5.0) return 'Удовлетворительное';
    if (score >= 3.0) return 'Плохое качество';
    return 'Очень плохое качество';
  }
  
  // Цвет качества воздуха по оценке
  static Color getAirQualityColorByScore(double score) {
    return Colors.white;
  }
}