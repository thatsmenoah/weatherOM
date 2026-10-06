import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/locale_manager.dart';
import '../utils/wmo_codes.dart';

/// Приведение сырых ответов API к той структуре, которую ждёт UI.
///
/// Вынесено отдельно от [WeatherService] намеренно: здесь нет ни HTTP, ни
/// геолокации — только чистые функции над картой. Их можно покрыть тестами и
/// вызывать без сети.
class WeatherNormalizer {
  WeatherNormalizer._();

  /// API иногда отдаёт int вместо double и наоборот, а в кеше числа уже
  /// разбираются как int/double/String. Приводим всё к double без исключений.
  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Первый элемент списка как double. Раньше здесь стояло `as num`, и один
  /// `null` в массиве от API ронял весь ответ целиком.
  static double firstDouble(List? list, [double fallback = 0.0]) {
    if (list == null || list.isEmpty) return fallback;
    final value = list.first;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int firstInt(List? list, [int fallback = 0]) {
    if (list == null || list.isEmpty) return fallback;
    final value = list.first;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String description(int code, LocaleManager localeManager) {
    return localeManager.getText(WmoCodes.descriptionKey(code));
  }

  static Map<String, dynamic> weather(Map<String, dynamic> data) {
    final localeManager = LocaleManager();
    final current = data['current'] ?? <String, dynamic>{};
    final daily = data['daily'] ?? <String, dynamic>{};

    final weatherCode = toInt(current['weathercode']);
    final isDay = toInt(current['is_day']) == 1;

    return {
      'name': localeManager.getText('current_location'),
      'coord': {'lat': 0, 'lon': 0},
      'main': {
        'temp': toDouble(current['temperature_2m']),
        'feels_like': toDouble(current['apparent_temperature']),
        'temp_min': firstDouble(daily['temperature_2m_min'] as List?),
        'temp_max': firstDouble(daily['temperature_2m_max'] as List?),
        'humidity': toInt(current['relativehumidity_2m']),
        'pressure': toDouble(current['pressure_msl'] ?? 1013.0),
      },
      'wind': {
        'speed': toDouble(current['windspeed_10m']),
        'deg': toInt(current['winddirection_10m']),
        'gust': null,
      },
      'weather': [
        {
          'description': description(weatherCode, localeManager),
          'icon': WmoCodes.icon(weatherCode, isDay: isDay),
          'main': WmoCodes.group(weatherCode),
        }
      ],
      'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'timezone': 0,
      'id': 0,
      'cod': 200,
      'visibility': toInt(current['visibility'] ?? 10000),
      'clouds': {'all': 0},
      '_extra': {
        'uvIndex': firstDouble(daily['uv_index_max'] as List?),
        'precipitationSum': firstDouble(daily['precipitation_sum'] as List?),
        'precipitationProbability':
            firstInt(daily['precipitation_probability_max'] as List?),
      },
    };
  }

  /// Сколько часов держим в почасовом прогнозе.
  ///
  /// 168 часов нужны не только карточке на 8 часов: почасовой список целиком
  /// используется как запасной источник для дневного блока, когда Open-Meteo
  /// не вернул `daily`, и подсказками приложения.
  static const int hourlyHours = 168;

  static Map<String, dynamic> forecast(Map<String, dynamic> data) {
    final hourly = data['hourly'] ?? <String, dynamic>{};
    final daily = data['daily'] ?? <String, dynamic>{};
    final localeManager = LocaleManager();

    final times = hourly['time'] as List?;
    final currentTime = data['current']?['time']?.toString();

    final list = <Map<String, dynamic>>[];
    if (times != null && times.isNotEmpty) {
      var startIndex = 0;
      if (currentTime != null) {
        for (int i = 0; i < times.length; i++) {
          if (times[i].toString().compareTo(currentTime) >= 0) {
            startIndex = i;
            break;
          }
        }
      }

      // Если до конца массива осталось меньше 8 часов, отступаем назад.
      if (startIndex + 8 > times.length) {
        startIndex = times.length - 8;
        if (startIndex < 0) startIndex = 0;
      }

      final endIndex = min(startIndex + hourlyHours, times.length);
      final precipProbs = hourly['precipitation_probability'] as List?;

      for (int i = startIndex; i < endIndex; i++) {
        final temp = toDouble(hourly['temperature_2m']?[i]);
        final weatherCode = toInt(hourly['weathercode']?[i]);
        final isDay = toInt(hourly['is_day']?[i]) == 1;

        list.add({
          'dt_txt': times[i],
          'main': {
            'temp': temp,
            'feels_like': toDouble(hourly['apparent_temperature']?[i] ?? temp),
            'humidity': toInt(hourly['relativehumidity_2m']?[i]),
            'pressure': toDouble(hourly['pressure_msl']?[i] ?? 1013),
          },
          'weather': [
            {
              'description': description(weatherCode, localeManager),
              'icon': WmoCodes.icon(weatherCode, isDay: isDay),
              'main': WmoCodes.group(weatherCode),
            }
          ],
          'wind': {
            'speed': toDouble(hourly['windspeed_10m']?[i]),
            'deg': toInt(hourly['winddirection_10m']?[i]),
          },
          'clouds': {'all': 0},
          'visibility': 10000,
          'pop': toDouble(precipProbs?[i]),
          'dt': 0,
        });
      }
    }

    return {'list': list, 'daily': dailyForecast(daily)};
  }

  static List<Map<String, dynamic>> dailyForecast(Map<String, dynamic> daily) {
    final times = daily['time'];
    if (times is! List || times.isEmpty) return const [];

    final count = min(times.length, 7);
    return [
      for (int i = 0; i < count; i++)
        {
          'dt': times[i],
          'weathercode': toInt(daily['weathercode']?[i]),
          'temp_max': toDouble(daily['temperature_2m_max']?[i]),
          'temp_min': toDouble(daily['temperature_2m_min']?[i]),
          'sunrise': daily['sunrise']?[i],
          'sunset': daily['sunset']?[i],
          'uv_index': toDouble(daily['uv_index_max']?[i]),
          'precipitation_sum': toDouble(daily['precipitation_sum']?[i]),
          'precipitation_probability':
              toInt(daily['precipitation_probability_max']?[i]),
          'wind_speed_max': toDouble(daily['windspeed_10m_max']?[i]),
          'wind_direction': toInt(daily['winddirection_10m_dominant']?[i]),
        }
    ];
  }

  static Map<String, dynamic> airQuality(Map<String, dynamic> data) {
    final hourly = data['hourly'] ?? <String, dynamic>{};
    final times = hourly['time'] as List?;

    final utcOffsetSeconds = data['utc_offset_seconds'] as int? ?? 0;
    final nowInLocation = DateTime.now().toUtc().add(
      Duration(seconds: utcOffsetSeconds),
    );

    var currentIndex = 0;
    if (times != null && times.isNotEmpty) {
      for (int i = 0; i < times.length; i++) {
        final parsed = DateTime.tryParse('${times[i]}Z');
        if (parsed == null) continue;
        if (parsed.isBefore(nowInLocation) || i == times.length - 1) {
          currentIndex = i;
        }
        if (parsed.isAfter(nowInLocation)) break;
      }
    }

    double valueAt(List? list, int index) {
      if (list == null || index >= list.length) return 0.0;
      final value = list[index];
      return value is num ? value.toDouble() : 0.0;
    }

    final pm25 = valueAt(hourly['pm2_5'] as List?, currentIndex);
    return {
      'list': [
        {
          'main': {'aqi': aqiFromPm25(pm25)},
          'components': {
            'pm2_5': pm25,
            'pm10': valueAt(hourly['pm10'] as List?, currentIndex),
            'co': valueAt(hourly['carbon_monoxide'] as List?, currentIndex),
            'no2': valueAt(hourly['nitrogen_dioxide'] as List?, currentIndex),
            'so2': valueAt(hourly['sulphur_dioxide'] as List?, currentIndex),
            'o3': valueAt(hourly['ozone'] as List?, currentIndex),
            'nh3': 0.0,
          }
        }
      ]
    };
  }

  static int aqiFromPm25(double pm25) {
    if (pm25 <= 10) return 1;
    if (pm25 <= 25) return 2;
    if (pm25 <= 50) return 3;
    if (pm25 <= 75) return 4;
    return 5;
  }

  /// Заглушка, когда качество воздуха недоступно: null вместо выдуманных
  /// чисел, чтобы UI показал «нет данных», а не правдоподобные выдумки.
  static Map<String, dynamic> airQualityFallback() {
    return {
      'list': [
        {
          'main': {'aqi': null},
          'components': {
            'pm2_5': null,
            'pm10': null,
            'co': null,
            'no2': null,
            'so2': null,
            'o3': null,
            'nh3': null,
          }
        }
      ]
    };
  }

  static Map<String, dynamic> sunData(Map<String, dynamic> data) {
    final daily = data['daily'] ?? <String, dynamic>{};
    try {
      final sunriseList = daily['sunrise'];
      final sunsetList = daily['sunset'];
      return {
        'sunrise': sunriseList is List && sunriseList.isNotEmpty
            ? DateTime.tryParse('${sunriseList.first}')
            : null,
        'sunset': sunsetList is List && sunsetList.isNotEmpty
            ? DateTime.tryParse('${sunsetList.first}')
            : null,
        'timezoneOffsetSeconds': data['utc_offset_seconds'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('WeatherNormalizer.sunData: не удалось разобрать время - $e');
      return {'sunrise': null, 'sunset': null, 'timezoneOffsetSeconds': 0};
    }
  }

  static Map<String, dynamic> extraMetrics(Map<String, dynamic> data) {
    final daily = data['daily'] ?? <String, dynamic>{};
    final hourly = data['hourly'] ?? <String, dynamic>{};

    final currentHourIndex = _currentHourIndex(hourly, data['current']?['time']);

    return {
      'dewPoint': _dewPoint(hourly, currentHourIndex),
      'visibility': _visibility(hourly, currentHourIndex),
      'uvIndex': firstDouble(daily['uv_index_max'] as List?),
      'precipitationProbability':
          firstInt(daily['precipitation_probability_max'] as List?),
      'shortwaveRadiation': _radiation(hourly, currentHourIndex),
    };
  }

  static int _currentHourIndex(Map<String, dynamic> hourly, dynamic currentTime) {
    final times = hourly['time'];
    if (times is! List || times.isEmpty) return 0;

    final now = currentTime?.toString();
    var index = 0;
    for (int i = 0; i < times.length; i++) {
      if (now == null || times[i].toString().compareTo(now) > 0) {
        index = i == 0 ? 0 : i - 1;
        break;
      }
      index = i;
    }
    return index;
  }

  /// Точка росы по формуле Магнуса. Раньше формула дублировалась в
  /// [WeatherService] и в экране активностей.
  static double? _dewPoint(Map<String, dynamic> hourly, int index) {
    final tempList = hourly['temperature_2m'];
    final humidityList = hourly['relativehumidity_2m'];
    if (tempList is! List || humidityList is! List) return null;
    if (index >= tempList.length || index >= humidityList.length) return null;

    final temp = toDouble(tempList[index]);
    final humidity = toDouble(humidityList[index]);
    if (temp == 0 || humidity <= 0) return null;

    const a = 17.27;
    const b = 237.7;
    final alpha = (a * temp) / (b + temp) + log(humidity / 100);
    final denominator = a - alpha;
    if (denominator == 0) return null;
    return (b * alpha) / denominator;
  }

  static double? _visibility(Map<String, dynamic> hourly, int index) {
    final list = hourly['visibility'];
    if (list is! List || index >= list.length) return null;
    final value = toDouble(list[index]);
    return value > 0 ? value : null;
  }

  static double? _radiation(Map<String, dynamic> hourly, int index) {
    final list = hourly['shortwave_radiation'];
    if (list is! List || index >= list.length) return null;
    final value = list[index];
    return value is num ? value.toDouble() : null;
  }
}
