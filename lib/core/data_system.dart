import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/locale_manager.dart';
import '../services/weather_normalizer.dart';

/// Файловое хранилище кеша погоды.
///
/// Кеш один на файл, поэтому запись защищена мьютексом: два перекрывающихся
/// сохранения (смена города во время сохраняющей записи) больше не пишут в
/// один файл одновременно. Запись атомарная — сначала во временный файл, потом
/// переименование, — так что убийство процесса посреди записи не оставляет
/// обрезанный json, из-за которого в следующий раз данные молча пропали бы.
class DataSystem {
  final String _fileName;

  Map<String, dynamic>? _cachedData;
  DateTime? _lastUpdateTime;

  /// Версия схемы кеша. Меняется, когда структура данных становится несовместимой
  /// с тем, что лежит на диске: старый файл просто пересоздастся, вместо того
  /// чтобы молча отдавать мусор.
  static const int _schemaVersion = 2;

  /// Все файлы кеша приложения. Нужен для «очистить всё» в настройках, чтобы
  /// кнопка не забывала про второстепенные кеши.
  static const List<String> cacheFileNames = [
    'weather_data.json',
    'activity_data.json',
  ];

  /// Свежим считаем кеш моложе этого срока. Раньше это правило применялось
  /// только на экране «Другое», а главный экран брал кеш любой давности.
  static const Duration cacheMaxAge = Duration(hours: 6);

  DataSystem({String fileName = 'weather_data.json'}) : _fileName = fileName;

  bool get hasData => _cachedData != null;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Копия кеша: наружу не отдаём внутреннюю карту, иначе мутация из виджета
  /// тихо меняла бы состояние хранилища.
  Map<String, dynamic>? get cachedData =>
      _cachedData == null ? null : Map<String, dynamic>.from(_cachedData!);

  bool get _isFresh {
    if (_lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!) <= cacheMaxAge;
  }

  /// Кеш пригоден для показа: есть погода и она не старше [cacheMaxAge].
  bool get isCacheUsable => _isFresh && _cachedData?['weather'] is Map;

  bool _hasSection(String key) => _cachedData?[key] is Map<String, dynamic>;

  bool get isWeatherValid => _isFresh && _hasSection('weather');
  bool get isForecastValid => _isFresh && _hasSection('forecast');
  bool get isAirQualityValid => _isFresh && _hasSection('airQuality');
  bool get isSunDataValid => _isFresh && _hasSection('sunData');
  bool get isExtraMetricsValid => _isFresh && _hasSection('extraMetrics');
  bool get isLocationValid => _isFresh && _cachedData?['locationDetails'] is Map;

  /// Сериализация записей в файл: пока пишет один, остальные ждут.
  Future<void> _writeLock = Future<void>.value();

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
      if (contents.trim().isEmpty) return;

      final rawData = json.decode(contents);
      if (rawData is! Map<String, dynamic>) {
        debugPrint('DataSystem: кеш имеет неизвестный формат, игнорируем');
        return;
      }

      // Кеш, записанный другой версией схемы, нельзя читать как есть.
      final version = rawData['schemaVersion'];
      if (version is! int || version < _schemaVersion) {
        debugPrint(
          'DataSystem: кеш версии $version устарел, будет перезаписан',
        );
        return;
      }

      _cachedData = _deserializeCache(rawData);
      _lastUpdateTime = DateTime.tryParse(
        _cachedData!['timestamp']?.toString() ?? '',
      );
    } catch (e) {
      // Битый кеш не должен мешать приложению: сбрасываем и идём в сеть.
      debugPrint('DataSystem: ошибка загрузки кеша - $e');
      _cachedData = null;
      _lastUpdateTime = null;
    }
  }

  Map<String, dynamic> _deserializeCache(Map<String, dynamic> raw) {
    return {
      'weather': _asMap(raw['weather']),
      'forecast': _asMap(raw['forecast']),
      'airQuality': _asMap(raw['airQuality']),
      'sunData': _deserializeSunData(_asMap(raw['sunData'])),
      'extraMetrics': _asMap(raw['extraMetrics']),
      'city': raw['city'],
      'lat': WeatherNormalizer.toDouble(raw['lat']),
      'lon': WeatherNormalizer.toDouble(raw['lon']),
      'timestamp': raw['timestamp'],
      'locationDetails': _asMap(raw['locationDetails']),
      'isLocationManuallySelected': raw['isLocationManuallySelected'] == true,
    };
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _deserializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise'] != null
          ? DateTime.tryParse(sun['sunrise'].toString())
          : null,
      'sunset': sun['sunset'] != null
          ? DateTime.tryParse(sun['sunset'].toString())
          : null,
      'timezoneOffsetSeconds':
          WeatherNormalizer.toInt(sun['timezoneOffsetSeconds']),
    };
  }

  Map<String, dynamic>? _serializeSunData(Map<String, dynamic>? sun) {
    if (sun == null) return null;
    return {
      'sunrise': sun['sunrise']?.toString(),
      'sunset': sun['sunset']?.toString(),
      'timezoneOffsetSeconds': sun['timezoneOffsetSeconds'] ?? 0,
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
    bool isLocationManuallySelected = false,
  }) {
    // Сохраняем снимок значений: между постановкой в очередь и реальной записью
    // поля экрана могут поменяться.
    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
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
      'isLocationManuallySelected': isLocationManuallySelected,
    };
    final savedAt = DateTime.now();

    final completer = Completer<void>();
    _writeLock = _writeLock.then((_) async {
      try {
        if (weatherData == null || weatherData.isEmpty) {
          debugPrint('DataSystem: попытка сохранить пустые данные');
          completer.complete();
          return;
        }

        final file = await _getFile();
        final tempFile = File('${file.path}.tmp');
        await tempFile.writeAsString(json.encode(payload));
        // Переименование атомарно: читатель увидит либо старый файл целиком,
        // либо новый целиком.
        await tempFile.rename(file.path);

        _cachedData = _deserializeCache(payload);
        _lastUpdateTime = savedAt;
        completer.complete();
      } catch (e) {
        debugPrint('DataSystem: ошибка сохранения - $e');
        completer.complete();
      }
    });
    return completer.future;
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

  /// Кеш, пригодный для показа: в нём есть блок погоды.
  ///
  /// Возраст здесь не проверяется намеренно: главный экран показывает кеш сразу
  /// и параллельно обновляет его с сети, а пользователь видит метку времени
  /// обновления. «Стоит ли вообще ходить в сеть» решает [isCacheUsable].
  Map<String, dynamic>? getValidCache() {
    if (_cachedData?['weather'] is! Map<String, dynamic>) return null;
    return cachedData;
  }

  Map<String, dynamic>? getAllCachedData() => cachedData;

  Map<String, dynamic>? getWeatherFromCache() => _asMap(_cachedData?['weather']);

  Map<String, dynamic>? getForecastFromCache() =>
      _asMap(_cachedData?['forecast']);

  Map<String, dynamic>? getAirQualityFromCache() =>
      _asMap(_cachedData?['airQuality']);

  Map<String, dynamic>? getSunDataFromCache() => _asMap(_cachedData?['sunData']);

  Map<String, dynamic>? getExtraMetricsFromCache() =>
      _asMap(_cachedData?['extraMetrics']);

  String? getCityFromCache() => _cachedData?['city'] as String?;

  /// Выбрана ли текущая локация вручную (поиском), а не по GPS.
  bool? isLocationManuallySelectedFromCache() {
    final value = _cachedData?['isLocationManuallySelected'];
    return value is bool ? value : null;
  }

  Map<String, dynamic>? getLocationDetailsFromCache() =>
      _asMap(_cachedData?['locationDetails']);

  double? getLatFromCache() {
    final value = _cachedData?['lat'];
    return value == null ? null : WeatherNormalizer.toDouble(value);
  }

  double? getLonFromCache() {
    final value = _cachedData?['lon'];
    return value == null ? null : WeatherNormalizer.toDouble(value);
  }

  String getLastUpdateTimeString() {
    final localeManager = LocaleManager();
    final updatedAt = _lastUpdateTime;
    if (updatedAt == null) return localeManager.getText('never');

    final difference = DateTime.now().difference(updatedAt);

    if (difference.inMinutes < 1) return localeManager.getText('just_now');
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${localeManager.getText('minutes_ago')}';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ${localeManager.getText('hours_ago')}';
    }
    return '${difference.inDays} ${localeManager.getText('days_ago')}';
  }

  /// Доля «свежести» кеша для индикатора обновления: 1 — только что сохранён,
  /// 0 — кеш старше [cacheMaxAge].
  double getCacheAgingProgress() {
    if (_lastUpdateTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    final ratio = elapsed.inSeconds / cacheMaxAge.inSeconds;
    return ratio.clamp(0.0, 1.0).toDouble();
  }
}
