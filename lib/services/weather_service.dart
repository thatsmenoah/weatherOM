import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/locale_manager.dart';
import 'weather_normalizer.dart';

/// Единый таймаут на сетевой запрос. Раньше по коду встречались 10, 15 и 16
/// секунд в зависимости от места.
const Duration kRequestTimeout = Duration(seconds: 15);

enum WeatherSource {
  openMeteo,
  cached,
}

/// Ошибка погодного API.
///
/// Раньше наружу летели голые `Exception`/`TypeError`, и вызывающий код ничего
/// не мог о них сказать. Свой тип позволяет отличить «сервис не ответил» от
/// внутренней ошибки разбора.
class WeatherApiException implements Exception {
  final String message;

  const WeatherApiException(this.message);

  @override
  String toString() => 'WeatherApiException: $message';
}

/// Запрос отменён, потому что начался более новый или экран закрылся.
class WeatherRequestCancelled implements Exception {
  const WeatherRequestCancelled();
}

class WeatherResponse {
  final Map<String, dynamic> weather;
  final Map<String, dynamic> forecast;
  final Map<String, dynamic> airQuality;
  final Map<String, dynamic> sunData;
  final Map<String, dynamic> extraMetrics;
  final WeatherSource source;
  final String? errorMessage;
  final Map<String, dynamic>? locationDetails;

  WeatherResponse({
    required this.weather,
    required this.forecast,
    required this.airQuality,
    required this.sunData,
    this.extraMetrics = const {},
    this.source = WeatherSource.openMeteo,
    this.errorMessage,
    this.locationDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'weather': weather,
      'forecast': forecast,
      'airQuality': airQuality,
      'sunData': sunData,
      'extraMetrics': extraMetrics,
      'source': source.index,
      'locationDetails': locationDetails,
    };
  }

  bool get isFromOpenMeteo => source == WeatherSource.openMeteo;
  bool get hasError => errorMessage != null;
}

class GeocodingResult {
  final String city;
  final String district;
  final String street;
  final String fullAddress;
  final String source;

  GeocodingResult({
    required this.city,
    required this.district,
    required this.street,
    required this.fullAddress,
    required this.source,
  });

  String get displayName {
    final String result;
    if (street.isNotEmpty) {
      result = street;
    } else if (district.isNotEmpty) {
      result = district;
    } else if (city.isNotEmpty) {
      result = city;
    } else {
      result = fullAddress.isNotEmpty ? fullAddress : 'Unknown';
    }
    return _capitalize(result);
  }

  String? get subtitle {
    if (street.isNotEmpty) {
      final parts = <String>[];
      if (district.isNotEmpty) parts.add(district);
      if (city.isNotEmpty && city != district) parts.add(city);
      if (parts.isNotEmpty) {
        return _capitalize(parts.join(', '));
      }
      return null;
    } else if (district.isNotEmpty) {
      return city.isNotEmpty ? _capitalize(city) : null;
    }
    return null;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'district': district,
      'street': street,
      'fullAddress': fullAddress,
      'source': source,
    };
  }

  factory GeocodingResult.fromMap(Map<String, dynamic> map) {
    return GeocodingResult(
      city: _asString(map['city']),
      district: _asString(map['district']),
      street: _asString(map['street']),
      fullAddress: _asString(map['fullAddress']),
      source: _asString(map['source'], fallback: 'unknown'),
    );
  }

  /// Безопасно приводит значение из кеша к строке.
  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.isEmpty ? fallback : value;
    return value.toString();
  }
}

/// Сетевая часть погоды: запросы к API и геолокация.
///
/// Приведение ответов к структуре для UI живёт в [WeatherNormalizer] — там нет
/// сети, поэтому его можно тестировать.
class WeatherService {
  WeatherService._();

  /// Общий клиент для запросов, у которых клиент не передан явно.
  ///
  /// Раньше каждый вызов создавал свой [http.Client] и закрывал его вместе с
  /// соединением, из-за чего Open-Meteo и геокодер не могли переиспользовать
  /// TCP/TLS-соединение и каждый запрос платил за рукопожатие.
  static final http.Client _sharedClient = http.Client();

  static http.Client _clientFor(http.Client? client) =>
      client ?? _sharedClient;

  /// Ключ геокодера. Если `.env` не загрузился, `dotenv.env` бросает исключение —
  /// раньше это уходило наружу и рушило весь запрос погоды, хотя без геокодинга
  /// приложение прекрасно работает на координатах.
  static String get _openCageApiKey {
    try {
      return dotenv.env['OPENCAGE_API_KEY'] ?? '';
    } catch (e) {
      debugPrint('WeatherService: .env не загружен - $e');
      return '';
    }
  }

  static Future<Map<String, dynamic>> _getJson(
    Uri uri,
    http.Client client,
  ) async {
    final response = await client.get(uri).timeout(kRequestTimeout);
    if (response.statusCode != 200) {
      throw WeatherApiException('HTTP ${response.statusCode} для $uri');
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw WeatherApiException('Неожиданный формат ответа для $uri');
    }
    return decoded;
  }

  /// Модель Open-Meteo, подходящая региону. У каждой есть запасная.
  static String _selectModel(double lat, double lon) {
    if (lon >= -10 && lon <= 60 && lat >= 35 && lat <= 70) {
      return 'icon_seamless';
    }
    if (lon > 60 && lon <= 180 && lat >= 40 && lat <= 75) {
      return 'jma_seamless';
    }
    if (lon >= -130 && lon <= -50 && lat >= 25 && lat <= 70) {
      return 'hrrr';
    }
    return 'gfs_seamless';
  }

  static Future<Map<String, dynamic>> _fetchWithModel(
    double lat,
    double lon,
    String model,
    http.Client client,
  ) {
    return _getJson(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$lat&longitude=$lon'
        '&models=$model'
          '&current=apparent_temperature,temperature_2m,relativehumidity_2m,'
          'windspeed_10m,winddirection_10m,pressure_msl,weathercode,visibility,is_day'
        '&wind_speed_unit=ms'
        '&hourly=temperature_2m,relativehumidity_2m,windspeed_10m,winddirection_10m,is_day,'
        'pressure_msl,weathercode,visibility,apparent_temperature,'
        'precipitation_probability,shortwave_radiation'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min,'
        'sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,'
        'windspeed_10m_max,winddirection_10m_dominant'
        '&timezone=auto'
        '&forecast_days=7'
        '&past_days=0',
      ),
      client,
    );
  }

  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const WeatherApiException('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const WeatherApiException('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const WeatherApiException(
        'Location permissions are permanently denied',
      );
    }

    // Свежий GPS-фикс на холодном старте может занимать минуты (особенно в
    // помещении). Раньше здесь ожидание было бесконечным, из-за чего при первом
    // запуске приложение висело на загрузке. Ограничиваем время и при неудаче
    // берём последнюю известную позицию — данные всё равно загрузятся.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      debugPrint('getCurrentPosition: timeout, trying last known position');
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      debugPrint('getCurrentPosition: using last known position');
      return lastKnown;
    }

    // Последняя попытка — низкая точность определяется по сети и обычно
    // отвечает быстро даже без GPS.
    debugPrint('getCurrentPosition: no last known, trying low accuracy');
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  static Future<GeocodingResult?> _reverseGeocodeOpenCage(
    double lat,
    double lon,
    LocaleManager localeManager,
    http.Client client,
  ) async {
    final apiKey = _openCageApiKey;
    if (apiKey.isEmpty || apiKey == 'your_opencage_api_key_here') {
      debugPrint('OpenCage API key not configured');
      return null;
    }

    try {
      final data = await _getJson(
        Uri.parse(
          'https://api.opencagedata.com/geocode/v1/json?'
          'q=$lat+$lon'
          '&key=$apiKey'
          '&language=${localeManager.languageCode}'
          '&pretty=1'
          '&no_annotations=1',
        ),
        client,
      );

      final results = data['results'];
      if (results is! List || results.isEmpty) {
        debugPrint('OpenCage: no results for $lat, $lon');
        return null;
      }

      final result = results.first;
      final components = result is Map
          ? (result['components'])
          : null;
      final Map<String, dynamic> componentsMap = components is Map
          ? Map<String, dynamic>.from(components)
          : const <String, dynamic>{};
      String pick(List<String> keys) {
        for (final key in keys) {
          final value = componentsMap[key];
          if (value is String && value.isNotEmpty) return value;
        }
        return '';
      }

      final road = pick(['road', 'pedestrian']);
      final houseNumber = pick(['house_number']);
      return GeocodingResult(
        city: pick(['city', 'town', 'village', 'municipality']),
        district: pick([
          'suburb',
          'neighbourhood',
          'city_district',
          'county',
        ]),
        street: road.isNotEmpty
            ? (houseNumber.isNotEmpty ? '$road, $houseNumber' : road)
            : '',
        fullAddress: result is Map ? '${result['formatted'] ?? ''}' : '',
        source: 'opencage',
      );
    } catch (e) {
      // Геокодирование — украшение: без него экран покажет координаты.
      debugPrint('OpenCage error: $e');
      return null;
    }
  }

  static Future<GeocodingResult> getLocationDetails(
    double lat,
    double lon,
    LocaleManager localeManager, {
    http.Client? client,
  }) async {
    final httpClient = _clientFor(client);
    final openCageResult = await _reverseGeocodeOpenCage(
      lat,
      lon,
      localeManager,
      httpClient,
    );
    if (openCageResult != null) {
      return openCageResult;
    }
    return GeocodingResult(
      city: '',
      district: '',
      street: '',
      fullAddress: '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
      source: 'coordinates',
    );
  }

  /// Сырые данные погоды, воздуха и солнца без типизации.
  ///
  /// [client] можно передать, чтобы прервать запрос закрытием клиента — этим
  /// пользуется экран погоды, когда пользователь успевает выбрать другой город
  /// или вернуться к текущей локации, пока предыдущий запрос ещё идёт.
  static Future<Map<String, dynamic>> fetchAllFromOpenMeteo(
    double lat,
    double lon, {
    http.Client? client,
  }) async {
    final httpClient = _clientFor(client);
    debugPrint('Open-Meteo request: $lat, $lon');

    final preferredModel = _selectModel(lat, lon);
    debugPrint('Selected model: $preferredModel');

    Map<String, dynamic>? result;
    Object? lastError;
    for (final model in [preferredModel, 'gfs_seamless']) {
      try {
        final data = await _fetchWithModel(lat, lon, model, httpClient);
        if (data.isNotEmpty) {
          debugPrint('Success with model: $model');
          result = data;
          break;
        }
      } on WeatherRequestCancelled {
        rethrow;
      } catch (e) {
        // Раньше здесь стояло `e as Exception?`: любая ошибка типа Error
        // (TypeError, StateError) вылетала из catch и рушила перебор моделей
        // целиком — то есть ровно тогда, когда он был нужен.
        debugPrint('Model $model failed: $e');
        lastError = e;
      }
    }

    if (result == null) {
      debugPrint('All weather models unavailable');
      throw lastError is Exception
          ? lastError
          : WeatherApiException('$lastError');
    }

    // Качество воздуха не зависит от выбранной модели погоды, поэтому при
    // неудаче отдаём заглушку, а не роняем весь ответ.
    Map<String, dynamic> airQualityData;
    try {
      airQualityData = WeatherNormalizer.airQuality(
        await _getJson(
          Uri.parse(
            'https://air-quality-api.open-meteo.com/v1/air-quality?'
            'latitude=$lat&longitude=$lon'
            '&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone'
            '&timezone=auto'
            '&forecast_days=1'
            '&past_days=0',
          ),
          httpClient,
        ),
      );
    } on WeatherRequestCancelled {
      rethrow;
    } catch (e) {
      debugPrint('Air quality unavailable, using fallback: $e');
      airQualityData = WeatherNormalizer.airQualityFallback();
    }

    final localeManager = LocaleManager();

    return {
      'weather': WeatherNormalizer.weather(result, localeManager),
      'forecast': WeatherNormalizer.forecast(result, localeManager),
      'airQuality': airQualityData,
      'sunData': WeatherNormalizer.sunData(result),
      'extraMetrics': WeatherNormalizer.extraMetrics(result),
    };
  }

  static Future<WeatherResponse> fetchAllWeatherData(
    double lat,
    double lon, {
    http.Client? client,
  }) async {
    final localeManager = LocaleManager();
    try {
      final data = await fetchAllFromOpenMeteo(lat, lon, client: client);
      final locationDetails = await getLocationDetails(
        lat,
        lon,
        localeManager,
        client: client,
      );
      return WeatherResponse(
        weather: data['weather'] as Map<String, dynamic>,
        forecast: data['forecast'] as Map<String, dynamic>,
        airQuality: data['airQuality'] as Map<String, dynamic>,
        sunData: data['sunData'] as Map<String, dynamic>,
        extraMetrics:
            data['extraMetrics'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
        source: WeatherSource.openMeteo,
        locationDetails: locationDetails.toMap(),
      );
    } on WeatherRequestCancelled {
      // Экран сам разберётся: ответ пришёл не вовремя и будет отброшен.
      return WeatherResponse(
        weather: {},
        forecast: {},
        airQuality: {},
        sunData: {},
        errorMessage: 'cancelled',
      );
    } catch (e) {
      debugPrint('fetchAllWeatherData error: $e');
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
}
