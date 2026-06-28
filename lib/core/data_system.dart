import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DataSystem {
  static const String _fileName = 'weather_data.json';
  static const int cacheDurationMinutes = 30;
  
  Map<String, dynamic>? _cachedData;
  DateTime? _lastUpdateTime;
  
  // Состояние хранилища
  bool get hasData => _cachedData != null;
  bool get isDataValid => _isCacheValid();
  DateTime? get lastUpdateTime => _lastUpdateTime;
  Map<String, dynamic>? get cachedData => _cachedData;
  
  // Получение пути к файлу
  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory(); // ← глубокое хранилище
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
  
  //  СЕРИАЛИЗАЦИЯ АСТРОНОМИИ 
  
  /// Преобразует DateTime в строки для JSON
  Map<String, dynamic>? _serializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise']?.toString(),
      'sunset': sun['sunset']?.toString(),
    };
  }
  
  /// Преобразует строки обратно в DateTime
  Map<String, dynamic>? _deserializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise'] != null ? DateTime.tryParse(sun['sunrise'].toString()) : null,
      'sunset': sun['sunset'] != null ? DateTime.tryParse(sun['sunset'].toString()) : null,
    };
  }
  
  /// Десериализует весь кэш (включая астрономию)
  Map<String, dynamic> _deserializeCache(Map<String, dynamic> raw) {
    return {
      'weather': raw['weather'],
      'forecast': raw['forecast'],
      'airQuality': raw['airQuality'],
      'sunData': _deserializeSunData(raw['sunData']),
      'city': raw['city'],
      'timestamp': raw['timestamp'],
    };
  }
  
  // Сохранение в файл
  Future<void> saveToCache({
    required Map<String, dynamic>? weatherData,
    required Map<String, dynamic>? forecastData,
    required Map<String, dynamic>? airQualityData,
    Map<String, dynamic>? sunData, // ПЕРЕИМЕНОВАНО
    required String cityName,
  }) async {
    try {
      final cacheData = {
        'weather': weatherData,
        'forecast': forecastData,
        'airQuality': airQualityData,
        'sunData': _serializeSunData(sunData), // СОЛНЦЕ
        'city': cityName,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final file = await _getFile();
      await file.writeAsString(json.encode(cacheData));
      
      _cachedData = _deserializeCache(cacheData); // ДЕСЕРИАЛИЗУЕМ ОБРАТНО
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

  // Получение ВСЕХ кэшированных данных (даже устаревших) — для холодного старта
  Map<String, dynamic>? getAllCachedData() {
    return _cachedData;
  }
  
  // Очистка хранилища
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
  
  // Получение конкретных данных
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
  
  Map<String, dynamic>? getAirQualityFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('airQuality')) {
      return _cachedData!['airQuality'];
    }
    return null;
  }
  
  // ДОБАВЛЕНО: получение астрономии из кэша
  Map<String, dynamic>? getSunDataFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('sunData')) {
      return _cachedData!['sunData'];
    }
    return null;
  }
  
  String? getCityFromCache() {
    if (_isCacheValid() && _cachedData != null && _cachedData!.containsKey('city')) {
      return _cachedData!['city'];
    }
    return null;
  }
  
  String getLastUpdateTimeString() {
    if (_lastUpdateTime == null) return 'Никогда';
    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);
    
    if (difference.inMinutes < 1) return 'Только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    if (difference.inHours < 24) return '${difference.inHours} ч назад';
    return '${difference.inDays} д назад';
  }
  
  double getCacheAgingProgress() {
    if (!hasData || _lastUpdateTime == null) return 1.0;
    final age = DateTime.now().difference(_lastUpdateTime!).inMinutes;
    return (age / cacheDurationMinutes).clamp(0.0, 1.0);
  }
}