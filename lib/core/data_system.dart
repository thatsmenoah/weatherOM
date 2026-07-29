import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DataSystem {
  final String _fileName;
  static const int cacheDurationMinutes = 30;
  
  Map<String, dynamic>? _cachedData;
  DateTime? _lastUpdateTime;
  
  // КОНСТРУКТОР С ИМЕНЕМ ФАЙЛА
  DataSystem({String fileName = 'weather_data.json'}) : _fileName = fileName;
  
  // Состояние хранилища
  bool get hasData => _cachedData != null;
  bool get isDataValid => _isCacheValid();
  DateTime? get lastUpdateTime => _lastUpdateTime;
  Map<String, dynamic>? get cachedData => _cachedData;
  
  // Получение пути к файлу
  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
  
  // Инициализация
  Future<void> init() async {
    await _loadFromStorage();
  }
  
  // Загрузка из файла
  Future<void> _loadFromStorage() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final rawData = json.decode(contents);
        if (rawData != null) {
          _cachedData = _deserializeCache(rawData);
          if (_cachedData != null && _cachedData!.containsKey('timestamp')) {
            _lastUpdateTime = DateTime.tryParse(_cachedData!['timestamp'].toString());
          }
        }
      }
    } catch (e) {
      _cachedData = null;
      _lastUpdateTime = null;
    }
  }
  
  // Проверка валидности кэша
  bool _isCacheValid() {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < cacheDurationMinutes;
  }
  
  // СЕРИАЛИЗАЦИЯ АСТРОНОМИИ 
  Map<String, dynamic>? _serializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise']?.toString(),
      'sunset': sun['sunset']?.toString(),
    };
  }
  
  Map<String, dynamic>? _deserializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise'] != null ? DateTime.tryParse(sun['sunrise'].toString()) : null,
      'sunset': sun['sunset'] != null ? DateTime.tryParse(sun['sunset'].toString()) : null,
    };
  }
  
  Map<String, dynamic> _deserializeCache(Map<String, dynamic> raw) {
    return {
      'weather': raw['weather'],
      'forecast': raw['forecast'],
      'airQuality': raw['airQuality'],
      'sunData': _deserializeSunData(raw['sunData']),
      'extraMetrics': raw['extraMetrics'],
      'city': raw['city'],
      'lat': raw['lat'],
      'lon': raw['lon'],
      'timestamp': raw['timestamp'],
      'locationDetails': raw['locationDetails'],
    };
  }
  
  // Сохранение в файл
  Future<void> saveToCache({
    required Map<String, dynamic>? weatherData,
    required Map<String, dynamic>? forecastData,
    required Map<String, dynamic>? airQualityData,
    Map<String, dynamic>? sunData,
    Map<String, dynamic>? extraMetrics,
    required String cityName,
    double? lat,
    double? lon,
    Map<String, dynamic>? locationDetails,
  }) async {
    try {
      // Нормализуем прогноз - убеждаемся, что у всех элементов есть влажность
      Map<String, dynamic>? normalizedForecast = forecastData;
      if (forecastData != null && forecastData['list'] != null) {
        final list = forecastData['list'] as List;
        normalizedForecast = Map<String, dynamic>.from(forecastData);
        final normalizedList = <Map<String, dynamic>>[];
        for (var item in list) {
          final normalizedItem = Map<String, dynamic>.from(item as Map);
          if (normalizedItem['main'] != null) {
            final main = Map<String, dynamic>.from(normalizedItem['main']);
            if (!main.containsKey('humidity') || main['humidity'] == null) {
              // Если влажности нет, добавляем из текущей погоды или 0
              if (weatherData != null && weatherData['main'] != null && 
                  weatherData['main']['humidity'] != null) {
                main['humidity'] = weatherData['main']['humidity'];
              } else {
                main['humidity'] = 0;
              }
            }
            normalizedItem['main'] = main;
          }
          normalizedList.add(normalizedItem);
        }
        normalizedForecast['list'] = normalizedList;
      }
      
      final cacheData = {
        'weather': weatherData,
        'forecast': normalizedForecast,
        'airQuality': airQualityData,
        'sunData': _serializeSunData(sunData),
        'extraMetrics': extraMetrics,
        'city': cityName,
        'lat': lat,
        'lon': lon,
        'timestamp': DateTime.now().toIso8601String(),
        'locationDetails': locationDetails,
      };
      
      final file = await _getFile();
      await file.writeAsString(json.encode(cacheData));
      
      _cachedData = _deserializeCache(cacheData);
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      // Игнорируем ошибку сохранения
    }
  }
  
  // Получение данных из хранилища (если валидны)
  Map<String, dynamic>? getValidCache() {
    if (_isCacheValid()) {
      return _cachedData;
    }
    return null;
  }

  Map<String, dynamic>? getAllCachedData() {
    return _cachedData;
  }
  
  Future<void> clearCache() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
      _cachedData = null;
      _lastUpdateTime = null;
    } catch (e) {
      // Игнорируем ошибку
    }
  }
  
  Map<String, dynamic>? getWeatherFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('weather')) {
      return _cachedData!['weather'];
    }
    return null;
  }
  
  Map<String, dynamic>? getForecastFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('forecast')) {
      return _cachedData!['forecast'];
    }
    return null;
  }
  
  // Получение прогноза с гарантированной влажностью
  Map<String, dynamic>? getForecastWithHumidity() {
    if (!_isCacheValid() || _cachedData == null) return null;
    
    final forecast = _cachedData!['forecast'];
    if (forecast == null) return null;
    
    final list = forecast['list'] as List?;
    if (list == null || list.isEmpty) return forecast;
    
    // Убеждаемся, что у каждого элемента есть humidity
    for (var item in list) {
      if (item['main'] != null && !item['main'].containsKey('humidity')) {
        final weather = getWeatherFromCache();
        if (weather != null && weather['main'] != null && weather['main']['humidity'] != null) {
          item['main']['humidity'] = weather['main']['humidity'];
        } else {
          item['main']['humidity'] = 0;
        }
      }
    }
    
    return forecast;
  }
  
  // Метод для получения влажности для конкретного элемента прогноза
  int? getHumidityForForecastItem(Map<String, dynamic> item) {
  if (item['main'] == null) return null;
  return item['main']['humidity'] as int?;

  }
  
  Map<String, dynamic>? getAirQualityFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('airQuality')) {
      return _cachedData!['airQuality'];
    }
    return null;
  }
  
  Map<String, dynamic>? getSunDataFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('sunData')) {
      return _cachedData!['sunData'];
    }
    return null;
  }
  
  Map<String, dynamic>? getExtraMetricsFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('extraMetrics')) {
      return _cachedData!['extraMetrics'];
    }
    return null;
  }
  
  String? getCityFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('city')) {
      return _cachedData!['city'];
    }
    return null;
  }
  
  Map<String, dynamic>? getLocationDetailsFromCache() {
    if (_cachedData != null && _cachedData!.containsKey('locationDetails')) {
      return _cachedData!['locationDetails'] as Map<String, dynamic>?;
    }
    return null;
  }
  
  double? getLatFromCache() {
    if (_cachedData != null && _cachedData!.containsKey('lat')) {
      return _cachedData!['lat'] as double?;
    }
    return null;
  }
  
  double? getLonFromCache() {
    if (_cachedData != null && _cachedData!.containsKey('lon')) {
      return _cachedData!['lon'] as double?;
    }
    return null;
  }
  
  String getLastUpdateTimeString() {
    if (_lastUpdateTime == null) return 'Никогда';
    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);
    
    if (difference.inMinutes < 1) return 'Только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин. назад';
    if (difference.inHours < 24) return '${difference.inHours} ч. назад';
    return '${difference.inDays} д. назад';
  }
  
  double getCacheAgingProgress() {
    if (!hasData || _lastUpdateTime == null) return 1.0;
    final age = DateTime.now().difference(_lastUpdateTime!).inMinutes;
    return (age / cacheDurationMinutes).clamp(0.0, 1.0);
  }
}