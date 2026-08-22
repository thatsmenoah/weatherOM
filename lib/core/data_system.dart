import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/locale_manager.dart';

class DataSystem {
  final String _fileName;
  
  static const int weatherCacheMinutes = 30;
  static const int forecastCacheMinutes = 60;

  Map<String, dynamic>? _cachedData;
  DateTime? _lastUpdateTime;

  DataSystem({String fileName = 'weather_data.json'}) : _fileName = fileName;

  bool get hasData => _cachedData != null;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  Map<String, dynamic>? get cachedData => _cachedData;

  bool get isWeatherValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < weatherCacheMinutes;
  }

  bool get isForecastValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < forecastCacheMinutes;
  }

  bool get isAirQualityValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < weatherCacheMinutes;
  }

  bool get isSunDataValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < weatherCacheMinutes;
  }

  bool get isExtraMetricsValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < weatherCacheMinutes;
  }

  bool get isLocationValid {
    if (_cachedData == null || _lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes < weatherCacheMinutes;
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> init() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;

      final contents = await file.readAsString();
      final rawData = json.decode(contents);
      if (rawData == null) return;

      _cachedData = _deserializeCache(rawData);
      if (_cachedData != null && _cachedData!.containsKey('timestamp')) {
        _lastUpdateTime = DateTime.tryParse(_cachedData!['timestamp'].toString());
      }
    } catch (e) {
      debugPrint('DataSystem: ошибка загрузки кеша - $e');
      _cachedData = null;
      _lastUpdateTime = null;
    }
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

  Map<String, dynamic>? _deserializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise'] != null ? DateTime.tryParse(sun['sunrise'].toString()) : null,
      'sunset': sun['sunset'] != null ? DateTime.tryParse(sun['sunset'].toString()) : null,
    };
  }

  Map<String, dynamic>? _serializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise']?.toString(),
      'sunset': sun['sunset']?.toString(),
    };
  }

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
      if (weatherData == null || weatherData.isEmpty) {
        debugPrint('DataSystem: попытка сохранить пустые данные');
        return;
      }

      final cacheData = {
        'weather': weatherData,
        'forecast': forecastData,
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
      debugPrint('DataSystem: ошибка сохранения - $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
      _cachedData = null;
      _lastUpdateTime = null;
      debugPrint('DataSystem: кеш очищен');
    } catch (e) {
      debugPrint('DataSystem: ошибка очистки - $e');
    }
  }

  Map<String, dynamic>? getValidCache() {
    if (isWeatherValid) {
      return _cachedData;
    }
    return null;
  }

  Map<String, dynamic>? getAllCachedData() {
    return _cachedData;
  }

  Map<String, dynamic>? getWeatherFromCache() {
    if (isWeatherValid && _cachedData != null && _cachedData!.containsKey('weather')) {
      return _cachedData!['weather'];
    }
    return null;
  }

  Map<String, dynamic>? getForecastFromCache() {
    if (isForecastValid && _cachedData != null && _cachedData!.containsKey('forecast')) {
      return _cachedData!['forecast'];
    }
    return null;
  }

  Map<String, dynamic>? getAirQualityFromCache() {
    if (isAirQualityValid && _cachedData != null && _cachedData!.containsKey('airQuality')) {
      return _cachedData!['airQuality'];
    }
    return null;
  }

  Map<String, dynamic>? getSunDataFromCache() {
    if (isSunDataValid && _cachedData != null && _cachedData!.containsKey('sunData')) {
      return _cachedData!['sunData'];
    }
    return null;
  }

  Map<String, dynamic>? getExtraMetricsFromCache() {
    if (isExtraMetricsValid && _cachedData != null && _cachedData!.containsKey('extraMetrics')) {
      return _cachedData!['extraMetrics'];
    }
    return null;
  }

  String? getCityFromCache() {
    if (isWeatherValid && _cachedData != null && _cachedData!.containsKey('city')) {
      return _cachedData!['city'];
    }
    return null;
  }

  Map<String, dynamic>? getLocationDetailsFromCache() {
    if (isLocationValid && _cachedData != null && _cachedData!.containsKey('locationDetails')) {
      return _cachedData!['locationDetails'] as Map<String, dynamic>?;
    }
    return null;
  }

  double? getLatFromCache() {
    if (isWeatherValid && _cachedData != null && _cachedData!.containsKey('lat')) {
      return _cachedData!['lat'] as double?;
    }
    return null;
  }

  double? getLonFromCache() {
    if (isWeatherValid && _cachedData != null && _cachedData!.containsKey('lon')) {
      return _cachedData!['lon'] as double?;
    }
    return null;
  }

  String getLastUpdateTimeString() {
    final localeManager = LocaleManager();

    if (_lastUpdateTime == null) return localeManager.getText('never');

    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);

    if (difference.inMinutes < 1) return localeManager.getText('just_now');
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${localeManager.getText('minutes_ago')}';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ${localeManager.getText('hours_ago')}';
    }
    return '${difference.inDays} ${localeManager.getText('days_ago')}';
  }

  double getCacheAgingProgress() {
    if (!hasData || _lastUpdateTime == null) return 1.0;
    final age = DateTime.now().difference(_lastUpdateTime!).inMinutes;
    return (age / weatherCacheMinutes).clamp(0.0, 1.0);
  }
}