import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/locale_manager.dart';
import '../services/weather_normalizer.dart';
import '../utils/map_utils.dart';

/// Р¤Р°Р№Р»РѕРІРѕРµ С…СЂР°РЅРёР»РёС‰Рµ РєРµС€Р° РїРѕРіРѕРґС‹.
///
/// РљРµС€ РѕРґРёРЅ РЅР° С„Р°Р№Р», РїРѕСЌС‚РѕРјСѓ Р·Р°РїРёСЃСЊ Р·Р°С‰РёС‰РµРЅР° РјСЊСЋС‚РµРєСЃРѕРј: РґРІР° РїРµСЂРµРєСЂС‹РІР°СЋС‰РёС…СЃСЏ
/// СЃРѕС…СЂР°РЅРµРЅРёСЏ (СЃРјРµРЅР° РіРѕСЂРѕРґР° РІРѕ РІСЂРµРјСЏ СЃРѕС…СЂР°РЅСЏСЋС‰РµР№ Р·Р°РїРёСЃРё) Р±РѕР»СЊС€Рµ РЅРµ РїРёС€СѓС‚ РІ
/// РѕРґРёРЅ С„Р°Р№Р» РѕРґРЅРѕРІСЂРµРјРµРЅРЅРѕ. Р—Р°РїРёСЃСЊ Р°С‚РѕРјР°СЂРЅР°СЏ вЂ” СЃРЅР°С‡Р°Р»Р° РІРѕ РІСЂРµРјРµРЅРЅС‹Р№ С„Р°Р№Р», РїРѕС‚РѕРј
/// РїРµСЂРµРёРјРµРЅРѕРІР°РЅРёРµ, вЂ” С‚Р°Рє С‡С‚Рѕ СѓР±РёР№СЃС‚РІРѕ РїСЂРѕС†РµСЃСЃР° РїРѕСЃСЂРµРґРё Р·Р°РїРёСЃРё РЅРµ РѕСЃС‚Р°РІР»СЏРµС‚
/// РѕР±СЂРµР·Р°РЅРЅС‹Р№ json, РёР·-Р·Р° РєРѕС‚РѕСЂРѕРіРѕ РІ СЃР»РµРґСѓСЋС‰РёР№ СЂР°Р· РґР°РЅРЅС‹Рµ РјРѕР»С‡Р° РїСЂРѕРїР°Р»Рё Р±С‹.
class DataSystem {
  final String _fileName;

  Map<String, dynamic>? _cachedData;
  DateTime? _lastUpdateTime;

  /// Р’РµСЂСЃРёСЏ СЃС…РµРјС‹ РєРµС€Р°. РњРµРЅСЏРµС‚СЃСЏ, РєРѕРіРґР° СЃС‚СЂСѓРєС‚СѓСЂР° РґР°РЅРЅС‹С… СЃС‚Р°РЅРѕРІРёС‚СЃСЏ РЅРµСЃРѕРІРјРµСЃС‚РёРјРѕР№
  /// СЃ С‚РµРј, С‡С‚Рѕ Р»РµР¶РёС‚ РЅР° РґРёСЃРєРµ: СЃС‚Р°СЂС‹Р№ С„Р°Р№Р» РїСЂРѕСЃС‚Рѕ РїРµСЂРµСЃРѕР·РґР°СЃС‚СЃСЏ, РІРјРµСЃС‚Рѕ С‚РѕРіРѕ
  /// С‡С‚РѕР±С‹ РјРѕР»С‡Р° РѕС‚РґР°РІР°С‚СЊ РјСѓСЃРѕСЂ.
  static const int _schemaVersion = 2;

  /// Р’СЃРµ С„Р°Р№Р»С‹ РєРµС€Р° РїСЂРёР»РѕР¶РµРЅРёСЏ. РќСѓР¶РµРЅ РґР»СЏ В«РѕС‡РёСЃС‚РёС‚СЊ РІСЃС‘В» РІ РЅР°СЃС‚СЂРѕР№РєР°С…, С‡С‚РѕР±С‹
  /// РєРЅРѕРїРєР° РЅРµ Р·Р°Р±С‹РІР°Р»Р° РїСЂРѕ РІС‚РѕСЂРѕСЃС‚РµРїРµРЅРЅС‹Рµ РєРµС€Рё.
  static const List<String> cacheFileNames = [
    'weather_data.json',
    'activity_data.json',
  ];

  /// РЎРІРµР¶РёРј СЃС‡РёС‚Р°РµРј РєРµС€ РјРѕР»РѕР¶Рµ СЌС‚РѕРіРѕ СЃСЂРѕРєР°. Р Р°РЅСЊС€Рµ СЌС‚Рѕ РїСЂР°РІРёР»Рѕ РїСЂРёРјРµРЅСЏР»РѕСЃСЊ
  /// С‚РѕР»СЊРєРѕ РЅР° СЌРєСЂР°РЅРµ В«Р”СЂСѓРіРѕРµВ», Р° РіР»Р°РІРЅС‹Р№ СЌРєСЂР°РЅ Р±СЂР°Р» РєРµС€ Р»СЋР±РѕР№ РґР°РІРЅРѕСЃС‚Рё.
  static const Duration cacheMaxAge = Duration(hours: 6);

  DataSystem({String fileName = 'weather_data.json'}) : _fileName = fileName;

  bool get hasData => _cachedData != null;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// РљРѕРїРёСЏ РєРµС€Р°: РЅР°СЂСѓР¶Сѓ РЅРµ РѕС‚РґР°С‘Рј РІРЅСѓС‚СЂРµРЅРЅСЋСЋ РєР°СЂС‚Сѓ, РёРЅР°С‡Рµ РјСѓС‚Р°С†РёСЏ РёР· РІРёРґР¶РµС‚Р°
  /// С‚РёС…Рѕ РјРµРЅСЏР»Р° Р±С‹ СЃРѕСЃС‚РѕСЏРЅРёРµ С…СЂР°РЅРёР»РёС‰Р°.
  Map<String, dynamic>? get cachedData =>
      _cachedData == null ? null : Map<String, dynamic>.from(_cachedData!);

  bool get _isFresh {
    if (_lastUpdateTime == null) return false;
    return DateTime.now().difference(_lastUpdateTime!) <= cacheMaxAge;
  }

  /// РљРµС€ РїСЂРёРіРѕРґРµРЅ РґР»СЏ РїРѕРєР°Р·Р°: РµСЃС‚СЊ РїРѕРіРѕРґР° Рё РѕРЅР° РЅРµ СЃС‚Р°СЂС€Рµ [cacheMaxAge].
  bool get isCacheUsable => _isFresh && _cachedData?['weather'] is Map;

  bool _hasSection(String key) => _cachedData?[key] is Map<String, dynamic>;

  bool get isWeatherValid => _isFresh && _hasSection('weather');
  bool get isForecastValid => _isFresh && _hasSection('forecast');
  bool get isAirQualityValid => _isFresh && _hasSection('airQuality');
  bool get isSunDataValid => _isFresh && _hasSection('sunData');
  bool get isExtraMetricsValid => _isFresh && _hasSection('extraMetrics');
  bool get isLocationValid => _isFresh && _cachedData?['locationDetails'] is Map;

  /// РЎРµСЂРёР°Р»РёР·Р°С†РёСЏ Р·Р°РїРёСЃРµР№ РІ С„Р°Р№Р»: РїРѕРєР° РїРёС€РµС‚ РѕРґРёРЅ, РѕСЃС‚Р°Р»СЊРЅС‹Рµ Р¶РґСѓС‚.
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
        debugPrint('DataSystem: РєРµС€ РёРјРµРµС‚ РЅРµРёР·РІРµСЃС‚РЅС‹Р№ С„РѕСЂРјР°С‚, РёРіРЅРѕСЂРёСЂСѓРµРј');
        return;
      }

      // РљРµС€, Р·Р°РїРёСЃР°РЅРЅС‹Р№ РґСЂСѓРіРѕР№ РІРµСЂСЃРёРµР№ СЃС…РµРјС‹, РЅРµР»СЊР·СЏ С‡РёС‚Р°С‚СЊ РєР°Рє РµСЃС‚СЊ.
      final version = rawData['schemaVersion'];
      if (version is! int || version < _schemaVersion) {
        debugPrint(
          'DataSystem: РєРµС€ РІРµСЂСЃРёРё $version СѓСЃС‚Р°СЂРµР», Р±СѓРґРµС‚ РїРµСЂРµР·Р°РїРёСЃР°РЅ',
        );
        return;
      }

      _cachedData = _deserializeCache(rawData);
      _lastUpdateTime = DateTime.tryParse(
        _cachedData!['timestamp']?.toString() ?? '',
      );
    } catch (e) {
      // Р‘РёС‚С‹Р№ РєРµС€ РЅРµ РґРѕР»Р¶РµРЅ РјРµС€Р°С‚СЊ РїСЂРёР»РѕР¶РµРЅРёСЋ: СЃР±СЂР°СЃС‹РІР°РµРј Рё РёРґС‘Рј РІ СЃРµС‚СЊ.
      debugPrint('DataSystem: РѕС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё РєРµС€Р° - $e');
      _cachedData = null;
      _lastUpdateTime = null;
    }
  }

  Map<String, dynamic> _deserializeCache(Map<String, dynamic> raw) {
    return {
      'weather': asMap(raw['weather']),
      'forecast': asMap(raw['forecast']),
      'airQuality': asMap(raw['airQuality']),
      'sunData': _deserializeSunData(asMap(raw['sunData'])),
      'extraMetrics': asMap(raw['extraMetrics']),
      'city': raw['city'],
      'lat': WeatherNormalizer.toDouble(raw['lat']),
      'lon': WeatherNormalizer.toDouble(raw['lon']),
      'timestamp': raw['timestamp'],
      'locationDetails': asMap(raw['locationDetails']),
      'isLocationManuallySelected': raw['isLocationManuallySelected'] == true,
    };
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
    // РЎРѕС…СЂР°РЅСЏРµРј СЃРЅРёРјРѕРє Р·РЅР°С‡РµРЅРёР№: РјРµР¶РґСѓ РїРѕСЃС‚Р°РЅРѕРІРєРѕР№ РІ РѕС‡РµСЂРµРґСЊ Рё СЂРµР°Р»СЊРЅРѕР№ Р·Р°РїРёСЃСЊСЋ
    // РїРѕР»СЏ СЌРєСЂР°РЅР° РјРѕРіСѓС‚ РїРѕРјРµРЅСЏС‚СЊСЃСЏ.
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
          debugPrint('DataSystem: РїРѕРїС‹С‚РєР° СЃРѕС…СЂР°РЅРёС‚СЊ РїСѓСЃС‚С‹Рµ РґР°РЅРЅС‹Рµ');
          completer.complete();
          return;
        }

        final file = await _getFile();
        final tempFile = File('${file.path}.tmp');
        await tempFile.writeAsString(json.encode(payload));
        // РџРµСЂРµРёРјРµРЅРѕРІР°РЅРёРµ Р°С‚РѕРјР°СЂРЅРѕ: С‡РёС‚Р°С‚РµР»СЊ СѓРІРёРґРёС‚ Р»РёР±Рѕ СЃС‚Р°СЂС‹Р№ С„Р°Р№Р» С†РµР»РёРєРѕРј,
        // Р»РёР±Рѕ РЅРѕРІС‹Р№ С†РµР»РёРєРѕРј.
        await tempFile.rename(file.path);

        _cachedData = _deserializeCache(payload);
        _lastUpdateTime = savedAt;
        completer.complete();
      } catch (e) {
        debugPrint('DataSystem: РѕС€РёР±РєР° СЃРѕС…СЂР°РЅРµРЅРёСЏ - $e');
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
      debugPrint('DataSystem: РєРµС€ РѕС‡РёС‰РµРЅ');
    } catch (e) {
      debugPrint('DataSystem: РѕС€РёР±РєР° РѕС‡РёСЃС‚РєРё - $e');
    }
  }

  /// РљРµС€, РїСЂРёРіРѕРґРЅС‹Р№ РґР»СЏ РїРѕРєР°Р·Р°: РІ РЅС‘Рј РµСЃС‚СЊ Р±Р»РѕРє РїРѕРіРѕРґС‹.
  ///
  /// Р’РѕР·СЂР°СЃС‚ Р·РґРµСЃСЊ РЅРµ РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ РЅР°РјРµСЂРµРЅРЅРѕ: РіР»Р°РІРЅС‹Р№ СЌРєСЂР°РЅ РїРѕРєР°Р·С‹РІР°РµС‚ РєРµС€ СЃСЂР°Р·Сѓ
  /// Рё РїР°СЂР°Р»Р»РµР»СЊРЅРѕ РѕР±РЅРѕРІР»СЏРµС‚ РµРіРѕ СЃ СЃРµС‚Рё, Р° РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РІРёРґРёС‚ РјРµС‚РєСѓ РІСЂРµРјРµРЅРё
  /// РѕР±РЅРѕРІР»РµРЅРёСЏ. В«РЎС‚РѕРёС‚ Р»Рё РІРѕРѕР±С‰Рµ С…РѕРґРёС‚СЊ РІ СЃРµС‚СЊВ» СЂРµС€Р°РµС‚ [isCacheUsable].
  Map<String, dynamic>? getValidCache() {
    if (_cachedData?['weather'] is! Map<String, dynamic>) return null;
    return cachedData;
  }

  Map<String, dynamic>? getAllCachedData() => cachedData;

  Map<String, dynamic>? getWeatherFromCache() => asMap(_cachedData?['weather']);

  Map<String, dynamic>? getForecastFromCache() =>
      asMap(_cachedData?['forecast']);

  Map<String, dynamic>? getAirQualityFromCache() =>
      asMap(_cachedData?['airQuality']);

  Map<String, dynamic>? getSunDataFromCache() => asMap(_cachedData?['sunData']);

  Map<String, dynamic>? getExtraMetricsFromCache() =>
      asMap(_cachedData?['extraMetrics']);

  String? getCityFromCache() => _cachedData?['city'] as String?;

  /// Р’С‹Р±СЂР°РЅР° Р»Рё С‚РµРєСѓС‰Р°СЏ Р»РѕРєР°С†РёСЏ РІСЂСѓС‡РЅСѓСЋ (РїРѕРёСЃРєРѕРј), Р° РЅРµ РїРѕ GPS.
  bool? isLocationManuallySelectedFromCache() {
    final value = _cachedData?['isLocationManuallySelected'];
    return value is bool ? value : null;
  }

  Map<String, dynamic>? getLocationDetailsFromCache() =>
      asMap(_cachedData?['locationDetails']);

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

  /// Р”РѕР»СЏ В«СЃРІРµР¶РµСЃС‚РёВ» РєРµС€Р° РґР»СЏ РёРЅРґРёРєР°С‚РѕСЂР° РѕР±РЅРѕРІР»РµРЅРёСЏ: 1 вЂ” С‚РѕР»СЊРєРѕ С‡С‚Рѕ СЃРѕС…СЂР°РЅС‘РЅ,
  /// 0 вЂ” РєРµС€ СЃС‚Р°СЂС€Рµ [cacheMaxAge].
  double getCacheAgingProgress() {
    if (_lastUpdateTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    final ratio = elapsed.inSeconds / cacheMaxAge.inSeconds;
    return ratio.clamp(0.0, 1.0).toDouble();
  }
}
