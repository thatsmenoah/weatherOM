import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ========== МОДЕЛЬ ДЛЯ ХРАНЕНИЯ ИСТОЧНИКА ДАННЫХ ==========

enum WeatherSource {
  openWeatherMap,
  openMeteo,
  cached,
}

class WeatherResponse {
  final Map<String, dynamic> weather;
  final Map<String, dynamic> forecast;
  final Map<String, dynamic> airQuality;
  final Map<String, dynamic> sunData;
  final WeatherSource source;
  final String? errorMessage;

  WeatherResponse({
    required this.weather,
    required this.forecast,
    required this.airQuality,
    required this.sunData,
    this.source = WeatherSource.openWeatherMap,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'weather': weather,
      'forecast': forecast,
      'airQuality': airQuality,
      'sunData': sunData,
      'source': source.index,
    };
  }

  bool get isFromOpenWeatherMap => source == WeatherSource.openWeatherMap;
  bool get isFromOpenMeteo => source == WeatherSource.openMeteo;
  bool get isFromCache => source == WeatherSource.cached;
  bool get hasError => errorMessage != null;
}

// ========== ОСНОВНОЙ СЕРВИС ==========

class WeatherService {
  static const String apiKey = '9b20db828ed34621c416eb444ec5cc3f';
  
  // ========== УНИВЕРСАЛЬНЫЕ ПАРСЕРЫ ЧИСЕЛ ==========
  
  static double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  static num _parseToNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  // ========== ГЕОЛОКАЦИЯ ==========
  
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Включите геолокацию');
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Разрешите доступ к геолокации');
      }
    }
    
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> searchCity(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse('https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=10&appid=$apiKey&lang=ru'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        return [];
      }
      
      List data = json.decode(response.body);
      return data.map((city) => {
        'name': city['name'],
        'lat': _parseToDouble(city['lat']),
        'lon': _parseToDouble(city['lon']),
        'country': city['country'],
        'state': city['state'] ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  // ========== OPENWEATHERMAP МЕТОДЫ ==========
  
  static Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки погоды');
    }
    
    Map<String, dynamic> rawData = json.decode(response.body);
    return _normalizeWeatherData(rawData);
  }
  
  static Future<Map<String, dynamic>> fetchForecast(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки прогноза');
    }
    
    Map<String, dynamic> rawData = json.decode(response.body);
    
    if (rawData['list'] != null) {
      rawData['list'] = (rawData['list'] as List).map((item) {
        return _normalizeForecastItem(item);
      }).toList();
    }
    
    return rawData;
  }
  
  static Future<Map<String, dynamic>> fetchAirQuality(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки качества воздуха');
    }
    
    return json.decode(response.body);
  }
  
  // ========== OPEN-METEO — ПОЛНЫЙ ЗАПАСНОЙ ВАРИАНТ ==========
  
  static Future<Map<String, dynamic>> fetchAllFromOpenMeteo(double lat, double lon) async {
    try {
      debugPrint('🌤️ Запрос к Open-Meteo для координат: $lat, $lon');
      
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?'
          'latitude=$lat&longitude=$lon'
          '&current_weather=true'
          '&hourly=temperature_2m,relativehumidity_2m,windspeed_10m,weathercode'
          '&daily=weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset'
          '&timezone=auto'
          '&forecast_days=3'
        ),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        throw Exception('Open-Meteo вернул статус ${response.statusCode}');
      }
      
      final data = json.decode(response.body);
      debugPrint('✅ Open-Meteo успешно ответил');
      return _normalizeOpenMeteoAllData(data);
    } catch (e) {
      debugPrint('❌ Ошибка Open-Meteo: $e');
      rethrow;
    }
  }
  
  static Map<String, dynamic> _normalizeOpenMeteoAllData(Map<String, dynamic> data) {
    final current = data['current_weather'] ?? {};
    final hourly = data['hourly'] ?? {};
    final daily = data['daily'] ?? {};
    
    final now = DateTime.now();
    final currentHourIndex = now.hour;
    
    int hourIndex = 0;
    if (hourly['time'] != null && hourly['time'] is List) {
      final times = hourly['time'] as List;
      for (int i = 0; i < times.length; i++) {
        if (i < times.length) {
          try {
            final time = DateTime.parse(times[i]);
            if (time.hour >= currentHourIndex || i == times.length - 1) {
              hourIndex = i;
              break;
            }
          } catch (_) {}
        }
      }
    }
    
    final weatherData = {
      'name': 'Текущее местоположение',
      'coord': {
        'lat': 0,
        'lon': 0,
      },
      'main': {
        'temp': current['temperature'] ?? 0.0,
        'feels_like': current['temperature'] ?? 0.0,
        'temp_min': daily['temperature_2m_min']?.isNotEmpty == true 
            ? daily['temperature_2m_min'][0] 
            : 0.0,
        'temp_max': daily['temperature_2m_max']?.isNotEmpty == true 
            ? daily['temperature_2m_max'][0] 
            : 0.0,
        'humidity': hourly['relativehumidity_2m']?.isNotEmpty == true 
            ? hourly['relativehumidity_2m'][hourIndex] 
            : 0,
        'pressure': 1013,
      },
      'wind': {
        'speed': current['windspeed'] ?? 0.0,
        'deg': 0,
        'gust': null,
      },
      'weather': [
        {
          'description': _getWeatherDescription(current['weathercode'] ?? 0),
          'icon': _getWeatherIcon(current['weathercode'] ?? 0),
          'main': _getWeatherMain(current['weathercode'] ?? 0),
        }
      ],
      'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'timezone': 0,
      'id': 0,
      'cod': 200,
      'visibility': 10000,
      'clouds': {'all': 0},
    };
    
    final forecastList = <Map<String, dynamic>>[];
    if (daily['time'] != null && daily['time'] is List) {
      final times = daily['time'] as List;
      for (int i = 0; i < times.length && i < 5; i++) {
        forecastList.add({
          'dt_txt': times[i] ?? '',
          'main': {
            'temp': daily['temperature_2m_max']?[i] ?? 0.0,
            'feels_like': daily['temperature_2m_max']?[i] ?? 0.0,
            'temp_min': daily['temperature_2m_min']?[i] ?? 0.0,
            'temp_max': daily['temperature_2m_max']?[i] ?? 0.0,
            'humidity': 0,
            'pressure': 1013,
          },
          'weather': [
            {
              'description': _getWeatherDescription(daily['weathercode']?[i] ?? 0),
              'icon': _getWeatherIcon(daily['weathercode']?[i] ?? 0),
              'main': _getWeatherMain(daily['weathercode']?[i] ?? 0),
            }
          ],
          'wind': {'speed': 0.0, 'deg': 0},
          'clouds': {'all': 0},
          'visibility': 10000,
          'pop': 0,
          'dt': 0,
        });
      }
    }
    
    DateTime? sunrise;
    DateTime? sunset;
    if (daily['sunrise']?.isNotEmpty == true) {
      sunrise = DateTime.tryParse(daily['sunrise'][0]);
    }
    if (daily['sunset']?.isNotEmpty == true) {
      sunset = DateTime.tryParse(daily['sunset'][0]);
    }
    
    return {
      'weather': weatherData,
      'forecast': {'list': forecastList},
      'airQuality': {
        'list': [
          {
            'main': {'aqi': 2},
            'components': {
              'co': 0,
              'no': 0,
              'no2': 0,
              'o3': 0,
              'so2': 0,
              'pm2_5': 0,
              'pm10': 0,
              'nh3': 0,
            }
          }
        ]
      },
      'sunData': {
        'sunrise': sunrise,
        'sunset': sunset,
      },
    };
  }
  
  static String _getWeatherDescription(int code) {
    const descriptions = {
      0: 'Ясное небо',
      1: 'Преимущественно ясно',
      2: 'Переменная облачность',
      3: 'Пасмурно',
      45: 'Туман',
      48: 'Туман с изморозью',
      51: 'Легкая морось',
      53: 'Умеренная морось',
      55: 'Сильная морось',
      56: 'Легкая ледяная морось',
      57: 'Сильная ледяная морось',
      61: 'Легкий дождь',
      63: 'Умеренный дождь',
      65: 'Сильный дождь',
      66: 'Легкий ледяной дождь',
      67: 'Сильный ледяной дождь',
      71: 'Легкий снегопад',
      73: 'Умеренный снегопад',
      75: 'Сильный снегопад',
      77: 'Снежная крупа',
      80: 'Легкий ливень',
      81: 'Умеренный ливень',
      82: 'Сильный ливень',
      85: 'Легкий снегопад',
      86: 'Сильный снегопад',
      95: 'Гроза',
      96: 'Гроза с градом',
      99: 'Сильная гроза с градом',
    };
    return descriptions[code] ?? 'Неизвестно';
  }
  
  static String _getWeatherIcon(int code) {
    if (code == 0) return '01d';
    if (code == 1) return '02d';
    if (code == 2) return '03d';
    if (code == 3) return '04d';
    if (code >= 45 && code <= 48) return '50d';
    if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67)) return '10d';
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return '13d';
    if (code >= 80 && code <= 82) return '09d';
    if (code >= 95 && code <= 99) return '11d';
    return '01d';
  }
  
  static String _getWeatherMain(int code) {
    if (code == 0) return 'Clear';
    if (code == 1 || code == 2) return 'Clouds';
    if (code == 3) return 'Clouds';
    if (code >= 45 && code <= 48) return 'Mist';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain';
    if (code >= 85 && code <= 86) return 'Snow';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clear';
  }
  
  // ========== КОМБИНИРОВАННЫЙ МЕТОД С FALLBACK ==========
  
  static Future<WeatherResponse> fetchAllWeatherDataWithFallback(
    double lat, 
    double lon, {
    bool forceOpenMeteo = false,
  }) async {
    if (forceOpenMeteo) {
      try {
        final data = await fetchAllFromOpenMeteo(lat, lon);
        return WeatherResponse(
          weather: data['weather']!,
          forecast: data['forecast']!,
          airQuality: data['airQuality']!,
          sunData: data['sunData']!,
          source: WeatherSource.openMeteo,
        );
      } catch (e) {
        return WeatherResponse(
          weather: {},
          forecast: {},
          airQuality: {},
          sunData: {},
          source: WeatherSource.openMeteo,
          errorMessage: e.toString(),
        );
      }
    }
    
    try {
      debugPrint('🌤️ Запрос к OpenWeatherMap...');
      
      final results = await Future.wait([
        fetchWeather(lat, lon),
        fetchForecast(lat, lon),
        fetchAirQuality(lat, lon),
        _fetchSunData(lat, lon),
      ]).timeout(const Duration(seconds: 15));
      
      debugPrint('✅ OpenWeatherMap успешно ответил');
      
      return WeatherResponse(
        weather: results[0],
        forecast: results[1],
        airQuality: results[2],
        sunData: results[3],
        source: WeatherSource.openWeatherMap,
      );
    } catch (e) {
      debugPrint('❌ OpenWeatherMap не отвечает: $e');
      debugPrint('🔄 Переключаемся на Open-Meteo...');
      
      try {
        final omData = await fetchAllFromOpenMeteo(lat, lon);
        debugPrint('✅ Open-Meteo успешно заменил OWM');
        return WeatherResponse(
          weather: omData['weather']!,
          forecast: omData['forecast']!,
          airQuality: omData['airQuality']!,
          sunData: omData['sunData']!,
          source: WeatherSource.openMeteo,
        );
      } catch (omError) {
        debugPrint('❌ Open-Meteo тоже не отвечает: $omError');
        return WeatherResponse(
          weather: {},
          forecast: {},
          airQuality: {},
          sunData: {},
          source: WeatherSource.openMeteo,
          errorMessage: 'Оба API недоступны: $omError',
        );
      }
    }
  }
  
  // ========== СОЛНЦЕ С FALLBACK ==========
  
  static Future<Map<String, dynamic>> _fetchSunData(double lat, double lon) async {
    try {
      return await fetchSunDataFromOpenMeteo(lat, lon);
    } catch (e) {
      debugPrint('Ошибка получения данных солнца: $e');
      return {
        'sunrise': null,
        'sunset': null,
      };
    }
  }
  
  static Future<Map<String, dynamic>> fetchSunDataFromOpenMeteo(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?'
          'latitude=$lat&longitude=$lon'
          '&daily=sunrise,sunset'
          '&timezone=auto'
          '&forecast_days=1'
        ),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки данных солнца');
      }
      
      final data = json.decode(response.body);
      return _normalizeSunData(data);
    } catch (e) {
      debugPrint('Ошибка Open-Meteo (солнце): $e');
      return {
        'sunrise': null,
        'sunset': null,
      };
    }
  }
  
  static Map<String, dynamic> _normalizeSunData(Map<String, dynamic> data) {
    try {
      if (data['daily'] == null) {
        return {'sunrise': null, 'sunset': null};
      }
      
      final daily = data['daily'];
      
      String? sunriseStr = daily['sunrise'] != null && (daily['sunrise'] as List).isNotEmpty
          ? daily['sunrise'][0]?.toString()
          : null;
      String? sunsetStr = daily['sunset'] != null && (daily['sunset'] as List).isNotEmpty
          ? daily['sunset'][0]?.toString()
          : null;
      
      DateTime? sunrise = sunriseStr != null ? DateTime.tryParse(sunriseStr) : null;
      DateTime? sunset = sunsetStr != null ? DateTime.tryParse(sunsetStr) : null;
      
      return {
        'sunrise': sunrise,
        'sunset': sunset,
      };
    } catch (e) {
      debugPrint('Ошибка нормализации данных солнца: $e');
      return {'sunrise': null, 'sunset': null};
    }
  }
  
  // ========== МЕТОД ДЛЯ АКТИВНОСТИ (ПОГОДА + КАЧЕСТВО ВОЗДУХА) ==========
  
  static Future<Map<String, dynamic>> fetchWeatherAndAirQuality(double lat, double lon) async {
    try {
      // Сначала пытаемся получить из OWM
      final results = await Future.wait([
        http.get(
          Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=ru'),
        ).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey'),
        ).timeout(const Duration(seconds: 10)),
      ]);
      
      if (results[0].statusCode != 200) {
        throw Exception('Ошибка загрузки погоды');
      }
      
      Map<String, dynamic> rawWeather = json.decode(results[0].body);
      
      return {
        'weather': _normalizeWeatherData(rawWeather),
        'airQuality': json.decode(results[1].body),
      };
    } catch (e) {
      // Если OWM не работает - пробуем Open-Meteo
      debugPrint('❌ OWM не отвечает в ActivityScreen: $e');
      debugPrint('🔄 Переключаемся на Open-Meteo...');
      
      try {
        final omData = await fetchAllFromOpenMeteo(lat, lon);
        return {
          'weather': omData['weather']!,
          'airQuality': omData['airQuality']!,
        };
      } catch (omError) {
        debugPrint('❌ Open-Meteo тоже не отвечает: $omError');
        rethrow;
      }
    }
  }
  
  // ========== НОВЫЙ МЕТОД: УФ-ИНДЕКС, ТОЧКА РОСЫ, ВИДИМОСТЬ, ВЕРОЯТНОСТЬ ОСАДКОВ, СОЛНЕЧНАЯ РАДИАЦИЯ ==========

static Future<Map<String, dynamic>> fetchExtraMetricsFromOpenMeteo(double lat, double lon) async {
  try {
    debugPrint('🌤️ Запрос доп. метрик к Open-Meteo...');

    final response = await http.get(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$lat&longitude=$lon'
        '&hourly=dew_point_2m,visibility,uv_index,precipitation_probability,shortwave_radiation'
        '&timezone=auto'
        '&forecast_hours=1',
      ),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Open-Meteo вернул статус ${response.statusCode}');
    }

    final data = json.decode(response.body);
    debugPrint('✅ Open-Meteo доп. метрики получены');

    final hourly = data['hourly'] ?? {};
    final times = hourly['time'] as List?;
    final dewPoints = hourly['dew_point_2m'] as List?;
    final visibilities = hourly['visibility'] as List?;
    final uvIndices = hourly['uv_index'] as List?;
    final precipProbs = hourly['precipitation_probability'] as List?;
    final shortwaveRads = hourly['shortwave_radiation'] as List?;

    int currentIndex = 0;
    if (times != null && times.isNotEmpty) {
      final now = DateTime.now();
      for (int i = 0; i < times.length; i++) {
        final time = DateTime.parse(times[i]);
        if (time.hour <= now.hour || i == times.length - 1) {
          currentIndex = i;
        }
        if (time.hour > now.hour) break;
      }
    }

    return {
      'dewPoint': dewPoints != null && currentIndex < dewPoints.length
          ? _parseToDouble(dewPoints[currentIndex])
          : null,
      'visibility': visibilities != null && currentIndex < visibilities.length
          ? _parseToDouble(visibilities[currentIndex])
          : null,
      'uvIndex': uvIndices != null && currentIndex < uvIndices.length
          ? _parseToDouble(uvIndices[currentIndex])
          : null,
      'precipitationProbability': precipProbs != null && currentIndex < precipProbs.length
          ? _parseToNum(precipProbs[currentIndex])
          : null,
      'shortwaveRadiation': shortwaveRads != null && currentIndex < shortwaveRads.length
          ? _parseToDouble(shortwaveRads[currentIndex])
          : null,
    };
  } catch (e) {
    debugPrint('❌ Ошибка получения доп. метрик: $e');
    return {
      'dewPoint': null,
      'visibility': null,
      'uvIndex': null,
      'precipitationProbability': null,
      'shortwaveRadiation': null,
    };
  }
}
  
  // ========== СТАРЫЙ МЕТОД ДЛЯ СОВМЕСТИМОСТИ ==========
  
  @Deprecated('Используйте fetchAllWeatherDataWithFallback')
  static Future<Map<String, dynamic>> fetchAllWeatherData(double lat, double lon) async {
    final response = await fetchAllWeatherDataWithFallback(lat, lon);
    if (response.hasError) {
      throw Exception(response.errorMessage);
    }
    return response.toMap();
  }
  
  // ========== НОРМАЛИЗАЦИЯ OWM ==========
  
  static Map<String, dynamic> _normalizeWeatherData(Map<String, dynamic> data) {
    try {
      if (data['main'] != null) {
        data['main']['temp'] = _parseToDouble(data['main']['temp']);
        data['main']['feels_like'] = _parseToDouble(data['main']['feels_like']);
        data['main']['temp_min'] = _parseToDouble(data['main']['temp_min']);
        data['main']['temp_max'] = _parseToDouble(data['main']['temp_max']);
        data['main']['pressure'] = _parseToNum(data['main']['pressure']);
        data['main']['humidity'] = _parseToNum(data['main']['humidity']);
        
        if (data['main']['sea_level'] != null) {
          data['main']['sea_level'] = _parseToNum(data['main']['sea_level']);
        }
        if (data['main']['grnd_level'] != null) {
          data['main']['grnd_level'] = _parseToNum(data['main']['grnd_level']);
        }
      }
      
      if (data['wind'] != null) {
        data['wind']['speed'] = _parseToDouble(data['wind']['speed']);
        data['wind']['deg'] = _parseToNum(data['wind']['deg']);
        data['wind']['gust'] = data['wind']['gust'] != null 
            ? _parseToDouble(data['wind']['gust']) 
            : null;
      }
      
      if (data['coord'] != null) {
        data['coord']['lat'] = _parseToDouble(data['coord']['lat']);
        data['coord']['lon'] = _parseToDouble(data['coord']['lon']);
      }
      
      if (data['visibility'] != null) {
        data['visibility'] = _parseToNum(data['visibility']);
      }
      
      if (data['clouds'] != null && data['clouds']['all'] != null) {
        data['clouds']['all'] = _parseToNum(data['clouds']['all']);
      }
      
      if (data['dt'] != null) data['dt'] = _parseToNum(data['dt']);
      if (data['timezone'] != null) data['timezone'] = _parseToNum(data['timezone']);
      if (data['id'] != null) data['id'] = _parseToNum(data['id']);
      if (data['cod'] != null) {
        data['cod'] = data['cod'] is String 
            ? int.tryParse(data['cod']) ?? 200 
            : _parseToNum(data['cod']);
      }
      
      return data;
    } catch (e) {
      return data;
    }
  }
  
  static Map<String, dynamic> _normalizeForecastItem(Map<String, dynamic> item) {
    try {
      if (item['main'] != null) {
        item['main']['temp'] = _parseToDouble(item['main']['temp']);
        item['main']['feels_like'] = _parseToDouble(item['main']['feels_like']);
        item['main']['temp_min'] = _parseToDouble(item['main']['temp_min']);
        item['main']['temp_max'] = _parseToDouble(item['main']['temp_max']);
        item['main']['pressure'] = _parseToNum(item['main']['pressure']);
        item['main']['humidity'] = _parseToNum(item['main']['humidity']);
        
        if (item['main']['sea_level'] != null) {
          item['main']['sea_level'] = _parseToNum(item['main']['sea_level']);
        }
        if (item['main']['grnd_level'] != null) {
          item['main']['grnd_level'] = _parseToNum(item['main']['grnd_level']);
        }
      }
      
      if (item['wind'] != null) {
        item['wind']['speed'] = _parseToDouble(item['wind']['speed']);
        item['wind']['deg'] = _parseToNum(item['wind']['deg']);
        if (item['wind']['gust'] != null) {
          item['wind']['gust'] = _parseToDouble(item['wind']['gust']);
        }
      }
      
      if (item['clouds'] != null && item['clouds']['all'] != null) {
        item['clouds']['all'] = _parseToNum(item['clouds']['all']);
      }
      
      if (item['visibility'] != null) {
        item['visibility'] = _parseToNum(item['visibility']);
      }
      
      if (item['pop'] != null) {
        item['pop'] = _parseToDouble(item['pop']);
      }
      
      if (item['dt'] != null) {
        item['dt'] = _parseToNum(item['dt']);
      }
      
      return item;
    } catch (e) {
      return item;
    }
  }
}

// ========== РАСШИРЕНИЯ ==========

extension SafeNumberParse on Map<String, dynamic> {
  double getDouble(String key) {
    final value = this[key];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  int getInt(String key) {
    final value = this[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  num getNum(String key) {
    final value = this[key];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    }
    return 0;
  }
  
  String getTempString(String key) {
    return '${getDouble(key).round()}°';
  }
  
  String getPercentString(String key) {
    return '${getNum(key)}%';
  }
}

// ========== МОДЕЛЬ ДАННЫХ ПОГОДЫ ==========

class WeatherData {
  final Map<String, dynamic> raw;
  
  WeatherData(this.raw);
  
  Map<String, dynamic>? _getMap(String key) {
    final value = raw[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
  
  double get temp {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get feelsLike {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['feels_like'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get tempMin {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp_min'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  double get tempMax {
    final main = _getMap('main');
    if (main == null) return 0.0;
    final value = main['temp_max'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  num get humidity {
    final main = _getMap('main');
    if (main == null) return 0;
    final value = main['humidity'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  num get pressure {
    final main = _getMap('main');
    if (main == null) return 0;
    final value = main['pressure'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  double get windSpeed {
    final wind = _getMap('wind');
    if (wind == null) return 0.0;
    final value = wind['speed'];
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
  
  num get windDeg {
    final wind = _getMap('wind');
    if (wind == null) return 0;
    final value = wind['deg'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? double.tryParse(value) ?? 0;
    return 0;
  }
  
  num get clouds {
    final clouds = _getMap('clouds');
    if (clouds == null) return 0;
    final value = clouds['all'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  num get visibility {
    final value = raw['visibility'];
    if (value == null) return 0;
    if (value is num) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  String get description {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['description'] ?? '';
    }
    return '';
  }
  
  String get icon {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['icon'] ?? '';
    }
    return '';
  }
  
  String get main {
    final weather = raw['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['main'] ?? '';
    }
    return '';
  }
  
  String get cityName => raw['name'] ?? '';
  
  String get tempString => '${temp.round()}°';
  String get feelsLikeString => 'Ощущается как ${feelsLike.round()}°';
  String get humidityString => '$humidity%';
  String get pressureString => '$pressure мм рт. ст.';
  String get windSpeedString => '${windSpeed.toStringAsFixed(1)} м/с';
  String get cloudsString => '$clouds%';
  String get visibilityString => '${(visibility.toDouble() / 1000).toStringAsFixed(1)} км';
}