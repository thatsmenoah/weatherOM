import 'package:flutter/material.dart';

/// Система генерации советов на основе погодных данных
/// Анализирует текущую погоду, прогноз и время суток
class TipsSystem {
  
  Map<String, dynamic>? analyzeWeatherForTips(
    Map<String, dynamic>? weatherData, 
    Map<String, dynamic>? forecastData
  ) {
    if (weatherData == null) return null;
    
    final now = DateTime.now();
    final sunrise = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunrise'] * 1000);
    final sunset = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunset'] * 1000);
    
    final timeToSunrise = sunrise.difference(now).inHours;
    final timeToSunset = sunset.difference(now).inHours;
    
    if (timeToSunrise >= 0 && timeToSunrise < 1) {
      return _createSunriseTip(sunrise);
    }
    
    if (timeToSunset >= 0 && timeToSunset < 1) {
      return _createSunsetTip(sunset);
    }
    
    final nextHourData = _getWeatherForNextHour(forecastData);
    
    if (nextHourData != null && _willSnowInNextHour(nextHourData)) {
      return _createSnowTip();
    }
    
    if (nextHourData != null && _willRainInNextHour(nextHourData)) {
      return _createRainTip(nextHourData);
    }
    
    return _createWeatherTip(weatherData);
  }
  
  Map<String, dynamic>? _getWeatherForNextHour(Map<String, dynamic>? forecastData) {
    if (forecastData == null) return null;
    
    final now = DateTime.now();
    final nextHour = now.add(const Duration(hours: 1));
    
    Map<String, dynamic>? closestForecast;
    Duration smallestDiff = const Duration(days: 365);
    
    for (var item in forecastData['list']) {
      final forecastTime = DateTime.parse(item['dt_txt']);
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
           pop > 0.3;
  }
  
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 23 || hour <= 4) return 'night';
    if (hour >= 5 && hour <= 10) return 'morning';
    if (hour >= 11 && hour <= 16) return 'day';
    return 'evening';
  }
  
  Map<String, dynamic> _createSnowTip() {
    final messages = [
      "Ожидается снег в ближайшее время.",
      "На улице снег - одевайтесь теплее.",
      "Возможна скользкая дорога, будьте аккуратны."
    ];
    
    return {
      'type': 'snow',
      'title': 'Снегопад',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createRainTip(Map<String, dynamic> hourData) {
    final pop = (hourData['pop'] ?? 0.5) * 100;
    
    final messages = [
      "Ожидается дождь - возьмите зонт.",
      "Возможны осадки, лучше одеться соответствующе.",
      "На улице может идти дождь, учитывайте это при выходе."
    ];
    
    final intensity = pop > 70 ? "сильный" : (pop > 40 ? "умеренный" : "небольшой");
    
    return {
      'type': 'rain',
      'title': 'Возможен $intensity дождь',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Вероятность: ${pop.round()}%',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSunriseTip(DateTime sunrise) {
    final messages = [
      "Скоро рассвет.",
      "Начинается новый день.",
      "Хорошее время для утреннего пробуждения."
    ];
    
    return {
      'type': 'sunrise',
      'title': 'Рассвет',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'В ${_formatTime(sunrise)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createSunsetTip(DateTime sunset) {
    final messages = [
      "Скоро закат.",
      "День подходит к завершению.",
      "Вечером станет темнее."
    ];
    
    return {
      'type': 'sunset',
      'title': 'Закат',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'В ${_formatTime(sunset)}',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  Map<String, dynamic> _createWeatherTip(Map<String, dynamic> weatherData) {
    final weatherMain = weatherData['weather'][0]['main'].toLowerCase();
    final temp = weatherData['main']['temp'].round();
    final feelsLike = weatherData['main']['feels_like'].round();
    final humidity = weatherData['main']['humidity'].toDouble();
    final timeOfDay = _getTimeOfDay();
    
    if (timeOfDay == 'night') {
      return _createNightTip(temp, weatherMain);
    }
    
    if (timeOfDay == 'morning') {
      return _createMorningTip(temp, humidity, weatherMain);
    }
    
    switch(weatherMain) {
      case 'clear':
        return _createClearSkyTip(temp, feelsLike);
      case 'clouds':
        return _createCloudsTip(temp);
      case 'rain':
        return _createRainyTip();
      case 'snow':
        return _createSnowyTip(temp);
      case 'thunderstorm':
        return _createThunderstormTip();
      case 'drizzle':
        return _createDrizzleTip();
      case 'mist':
      case 'fog':
      case 'haze':
        return _createFoggyTip();
      default:
        return _createDefaultTip();
    }
  }
  
  Map<String, dynamic> _createNightTip(int temp, String weatherMain) {
    final messages = [
      "Сейчас ночь, лучше отдохнуть.",
      "На улице $temp°C - проветрите перед сном.",
      "Температура $temp°C, спите в комфортных условиях."
    ];
    
    return {
      'type': 'night',
      'title': 'Ночь',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.nightlight_round,
    };
  }
  
  Map<String, dynamic> _createMorningTip(int temp, double humidity, String weatherMain) {
    if (temp <= 5) {
      return {
        'type': 'morning',
        'title': 'Холодное утро',
        'message': 'На улице $temp°C, одевайтесь теплее.',
        'time': '$temp°C',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    if (humidity > 70) {
      return {
        'type': 'morning',
        'title': 'Влажное утро',
        'message': 'Температура $temp°C, влажность высокая - возможна духота.',
        'time': '${humidity.round()}%',
        'color': const Color(0xFF9E9E9E),
        'icon': Icons.wb_sunny,
      };
    }
    
    final messages = [
      "Утро комфортное, можно проветрить помещение.",
      "На улице $temp°C - нормальная погода для начала дня.",
      "Свежий воздух, хорошее утро."
    ];
    
    return {
      'type': 'morning',
      'title': 'Утро',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createClearSkyTip(int temp, int feelsLike) {
    final messages = [
      "Ясная погода, хорошее время для прогулки.",
      "Солнечно, можно выйти на улицу.",
      "Комфортная погода для активности."
    ];
    
    return {
      'type': 'clear',
      'title': 'Ясно',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Ощущается как $feelsLike°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.wb_sunny,
    };
  }
  
  Map<String, dynamic> _createCloudsTip(int temp) {
    final messages = [
      "Облачно, без осадков.",
      "Пасмурно, но стабильно.",
      "Нормальная погода для дел вне дома."
    ];
    
    return {
      'type': 'clouds',
      'title': 'Облачно',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.cloud,
    };
  }
  
  Map<String, dynamic> _createRainyTip() {
    final messages = [
      "Идёт дождь, лучше взять зонт.",
      "Осадки на улице, учитывайте это.",
      "Мокрая погода, будьте осторожны."
    ];
    
    return {
      'type': 'rain',
      'title': 'Дождь',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Осадки',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.beach_access,
    };
  }
  
  Map<String, dynamic> _createSnowyTip(int temp) {
    final messages = [
      "Снег на улице, одевайтесь теплее.",
      "Зимняя погода, возможен гололёд.",
      "Холодно и снежно."
    ];
    
    return {
      'type': 'snow',
      'title': 'Снег',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': '$temp°C',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.ac_unit,
    };
  }
  
  Map<String, dynamic> _createThunderstormTip() {
    final messages = [
      "Гроза, лучше оставаться в помещении.",
      "Штормовая погода, соблюдайте осторожность.",
      "Возможны разряды молний."
    ];
    
    return {
      'type': 'thunderstorm',
      'title': 'Гроза',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Опасные условия',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.flash_on,
    };
  }
  
  Map<String, dynamic> _createDrizzleTip() {
    final messages = [
      "Морось, возможна влажность.",
      "Лёгкие осадки.",
      "Слабый дождь."
    ];
    
    return {
      'type': 'drizzle',
      'title': 'Морось',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Небольшие осадки',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.grain,
    };
  }
  
  Map<String, dynamic> _createFoggyTip() {
    final messages = [
      "Туман, ограниченная видимость.",
      "Будьте осторожны на дороге.",
      "Плохая видимость."
    ];
    
    return {
      'type': 'fog',
      'title': 'Туман',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Сниженная видимость',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.foggy,
    };
  }
  
  Map<String, dynamic> _createDefaultTip() {
    final messages = [
      "Обычная погода, действуйте по ситуации.",
      "Одевайтесь по погоде.",
      "Следите за изменениями прогноза."
    ];
    
    return {
      'type': 'default',
      'title': 'Совет',
      'message': messages[DateTime.now().millisecond % messages.length],
      'time': 'Без особенностей',
      'color': const Color(0xFF9E9E9E),
      'icon': Icons.coffee,
    };
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}