import 'package:flutter/material.dart';
import '../core/locale_manager.dart';

class TipsSystem {
  
  Map<String, dynamic>? analyzeWeatherForTips(
    Map<String, dynamic>? weatherData, 
    Map<String, dynamic>? forecastData,
    Map<String, dynamic>? sunData, // ← НОВЫЙ ПАРАМЕТР
  ) {
    if (weatherData == null) return null;
    
    final localeManager = LocaleManager();
    final timezoneOffsetSeconds = sunData?['timezoneOffsetSeconds'] as int? ?? 0;
    final now = _toWallClock(DateTime.now().toUtc().add(
      Duration(seconds: timezoneOffsetSeconds),
    ));
    
    // 🔥 ИСПОЛЬЗУЕМ sunData вместо weatherData['_extra']
    DateTime? sunrise;
    DateTime? sunset;
    
    if (sunData != null) {
      final sunriseRaw = sunData['sunrise'];
      final sunsetRaw = sunData['sunset'];
      
      if (sunriseRaw is DateTime) {
        sunrise = sunriseRaw;
      } else if (sunriseRaw is String) {
        sunrise = DateTime.tryParse(sunriseRaw);
      }
      
      if (sunsetRaw is DateTime) {
        sunset = sunsetRaw;
      } else if (sunsetRaw is String) {
        sunset = DateTime.tryParse(sunsetRaw);
      }
    }
    
    if (sunrise != null && sunset != null) {
      final timeToSunrise = _toWallClock(sunrise).difference(now).inHours;
      final timeToSunset = _toWallClock(sunset).difference(now).inHours;
      
      if (timeToSunrise >= 0 && timeToSunrise < 1) {
        return _createSunriseTip(sunrise, localeManager);
      }
      
      if (timeToSunset >= 0 && timeToSunset < 1) {
        return _createSunsetTip(sunset, localeManager);
      }
    }
    
    final nextHourData = _getWeatherForNextHour(
      forecastData,
      timezoneOffsetSeconds,
    );
    
    if (nextHourData != null && _willSnowInNextHour(nextHourData)) {
      return _createSnowTip(localeManager);
    }
    
    if (nextHourData != null && _willRainInNextHour(nextHourData)) {
      return _createRainTip(nextHourData, localeManager);
    }
    
    return _createWeatherTip(weatherData, localeManager);
  }
  
  DateTime _toWallClock(DateTime time) {
    return DateTime.utc(time.year, time.month, time.day, time.hour, time.minute);
  }

  Map<String, dynamic>? _getWeatherForNextHour(
    Map<String, dynamic>? forecastData,
    int timezoneOffsetSeconds,
  ) {
    if (forecastData == null) return null;
    final rawList = forecastData['list'];
    if (rawList is! List) return null;
    
    final now = DateTime.now();
    final nextHour = now.add(const Duration(hours: 1));
    
    Map<String, dynamic>? closestForecast;
    Duration smallestDiff = const Duration(days: 365);
    
    for (final rawItem in rawList) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      if (item['dt_txt'] is! String) continue;
      final parsedTime = DateTime.tryParse(item['dt_txt'] as String);
      final forecastTime = parsedTime == null ? null : _toWallClock(parsedTime);
      if (forecastTime == null) continue;
      final diff = forecastTime.difference(nextHour).abs();
      
      if (diff < smallestDiff && diff <= const Duration(minutes: 90)) {
        smallestDiff = diff;
        closestForecast = item;
      }
    }
    
    return closestForecast;
  }
  
  bool _willSnowInNextHour(Map<String, dynamic> hourData) {
    final weather = hourData['weather'][0]['main'].toString().toLowerCase();
    final description = hourData['weather'][0]['description'].toString().toLowerCase();
    
    return weather.contains('snow') || 
           description.contains('снег') ||
           (hourData['main']['temp'] <= 2 && weather.contains('rain'));
  }
  
  bool _willRainInNextHour(Map<String, dynamic> hourData) {
    final weather = hourData['weather'][0]['main'].toString().toLowerCase();
    final pop = hourData['pop'] ?? 0;
    
    return weather.contains('rain') || 
           weather.contains('drizzle') ||
           pop > 30;
  }
  
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour <= 4) return 'night';
    if (hour >= 5 && hour <= 10) return 'morning';
    if (hour >= 11 && hour <= 16) return 'day';
    return 'evening';
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  Map<String, dynamic> _createSnowTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_snow_msg1'),
      localeManager.getText('tip_snow_msg2'),
      localeManager.getText('tip_snow_msg3'),
    ];
    
    return {
      'type': 'snow',
      'title': localeManager.getText('tip_snow_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createRainTip(Map<String, dynamic> hourData, LocaleManager localeManager) {
    final pop = (hourData['pop'] ?? 0.5);
    
    final messages = [
      localeManager.getText('tip_rain_msg1'),
      localeManager.getText('tip_rain_msg2'),
      localeManager.getText('tip_rain_msg3'),
    ];
    
    String intensityKey;
    if (pop > 70) {
      intensityKey = 'tip_rain_heavy';
    } else if (pop > 40) {
      intensityKey = 'tip_rain_moderate';
    } else {
      intensityKey = 'tip_rain_light';
    }
    final intensity = localeManager.getText(intensityKey);
    
    return {
      'type': 'rain',
      'title': '${localeManager.getText('tip_rain_title')} $intensity',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${localeManager.getText('precipitation_prob')}: ${pop.round()}%',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSunriseTip(
    DateTime sunrise, 
    LocaleManager localeManager,
  ) {
    final messages = [
      localeManager.getText('tip_sunrise_msg1'),
      localeManager.getText('tip_sunrise_msg2'),
      localeManager.getText('tip_sunrise_msg3'),
    ];
    
    return {
      'type': 'sunrise',
      'title': localeManager.getText('tip_sunrise_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${localeManager.getText('sunrise')} ${_formatTime(sunrise)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createSunsetTip(
    DateTime sunset, 
    LocaleManager localeManager,
  ) {
    final messages = [
      localeManager.getText('tip_sunset_msg1'),
      localeManager.getText('tip_sunset_msg2'),
    ];
    
    return {
      'type': 'sunset',
      'title': localeManager.getText('tip_sunset_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${localeManager.getText('sunset')} ${_formatTime(sunset)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  Map<String, dynamic> _createWeatherTip(Map<String, dynamic> weatherData, LocaleManager localeManager) {
    final weatherMain = weatherData['weather'][0]['main'].toLowerCase();
    final temp = weatherData['main']['temp'].round();
    final feelsLike = weatherData['main']['feels_like'].round();
    final humidity = weatherData['main']['humidity'].toDouble();
    final timeOfDay = _getTimeOfDay();
    
    if (timeOfDay == 'night') {
      return _createNightTip(temp, weatherMain, localeManager);
    }
    
    if (timeOfDay == 'morning') {
      return _createMorningTip(temp, humidity, weatherMain, localeManager);
    }
    
    switch(weatherMain) {
      case 'clear':
        return _createClearSkyTip(temp, feelsLike, localeManager);
      case 'clouds':
        return _createCloudsTip(temp, localeManager);
      case 'rain':
        return _createRainyTip(localeManager);
      case 'snow':
        return _createSnowyTip(temp, localeManager);
      case 'thunderstorm':
        return _createThunderstormTip(localeManager);
      case 'drizzle':
        return _createDrizzleTip(localeManager);
      case 'mist':
      case 'fog':
      case 'haze':
        return _createFoggyTip(localeManager);
      default:
        return _createDefaultTip(localeManager);
    }
  }
  
  Map<String, dynamic> _createNightTip(int temp, String weatherMain, LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_night_msg1'),
      localeManager.getTextWithArgs('tip_night_msg2', {'temp': temp.toString()}),
      localeManager.getTextWithArgs('tip_night_msg3', {'temp': temp.toString()}),
    ];
    
    return {
      'type': 'night',
      'title': localeManager.getText('tip_night_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  Map<String, dynamic> _createMorningTip(int temp, double humidity, String weatherMain, LocaleManager localeManager) {
    if (temp <= 5) {
      return {
        'type': 'morning',
        'title': localeManager.getText('tip_morning_cold_title'),
        'message': localeManager.getTextWithArgs('tip_morning_cold_msg', {'temp': temp.toString()}),
        'time': '$temp°C',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    if (humidity > 70) {
      return {
        'type': 'morning',
        'title': localeManager.getText('tip_morning_humid_title'),
        'message': localeManager.getTextWithArgs('tip_morning_humid_msg', {'temp': temp.toString()}),
        'time': '${humidity.round()}%',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    final messages = [
      localeManager.getText('tip_morning_msg1'),
      localeManager.getTextWithArgs('tip_morning_msg2', {'temp': temp.toString()}),
      localeManager.getText('tip_morning_msg3'),
    ];
    
    return {
      'type': 'morning',
      'title': localeManager.getText('tip_morning_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createClearSkyTip(int temp, int feelsLike, LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_clear_msg1'),
      localeManager.getText('tip_clear_msg2'),
      localeManager.getText('tip_clear_msg3'),
    ];
    
    return {
      'type': 'clear',
      'title': localeManager.getText('tip_clear_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${localeManager.getText('feels_like')} $feelsLike°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createCloudsTip(int temp, LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_clouds_msg1'),
      localeManager.getText('tip_clouds_msg2'),
      localeManager.getText('tip_clouds_msg3'),
    ];
    
    return {
      'type': 'clouds',
      'title': localeManager.getText('tip_clouds_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.cloud,
    };
  }
  
  Map<String, dynamic> _createRainyTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_rainy_msg1'),
      localeManager.getText('tip_rainy_msg2'),
      localeManager.getText('tip_rainy_msg3'),
    ];
    
    return {
      'type': 'rain',
      'title': localeManager.getText('tip_rainy_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': localeManager.getText('precipitation'),
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSnowyTip(int temp, LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_snowy_msg1'),
      localeManager.getText('tip_snowy_msg2'),
      localeManager.getText('tip_snowy_msg3'),
    ];
    
    return {
      'type': 'snow',
      'title': localeManager.getText('tip_snowy_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createThunderstormTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_thunder_msg1'),
      localeManager.getText('tip_thunder_msg2'),
      localeManager.getText('tip_thunder_msg3'),
    ];
    
    return {
      'type': 'thunderstorm',
      'title': localeManager.getText('tip_thunder_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': localeManager.getText('precipitation'),
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.flash_on,
    };
  }
  
  Map<String, dynamic> _createDrizzleTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_drizzle_msg1'),
      localeManager.getText('tip_drizzle_msg2'),
      localeManager.getText('tip_drizzle_msg3'),
    ];
    
    return {
      'type': 'drizzle',
      'title': localeManager.getText('tip_drizzle_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': localeManager.getText('precipitation'),
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.grain,
    };
  }
  
  Map<String, dynamic> _createFoggyTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_fog_msg1'),
      localeManager.getText('tip_fog_msg2'),
      localeManager.getText('tip_fog_msg3'),
    ];
    
    return {
      'type': 'fog',
      'title': localeManager.getText('tip_fog_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': localeManager.getText('visibility'),
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.foggy,
    };
  }
  
  Map<String, dynamic> _createDefaultTip(LocaleManager localeManager) {
    final messages = [
      localeManager.getText('tip_default_msg1'),
      localeManager.getText('tip_default_msg2'),
      localeManager.getText('tip_default_msg3'),
    ];
    
    return {
      'type': 'default',
      'title': localeManager.getText('tip_default_title'),
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': localeManager.getText('no_data'),
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.coffee,
    };
  }
}