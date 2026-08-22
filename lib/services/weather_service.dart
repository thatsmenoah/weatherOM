import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../core/locale_manager.dart';

enum WeatherSource {
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
  final Map<String, dynamic>? locationDetails;

  WeatherResponse({
    required this.weather,
    required this.forecast,
    required this.airQuality,
    required this.sunData,
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
    String result;
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
      city: map['city'] ?? '',
      district: map['district'] ?? '',
      street: map['street'] ?? '',
      fullAddress: map['fullAddress'] ?? '',
      source: map['source'] ?? 'unknown',
    );
  }
}

class WeatherService {
  // ==================== API КЛЮЧИ ИЗ .ENV ====================
  static String get _openCageApiKey {
    final key = dotenv.env['OPENCAGE_API_KEY'];
    return key ?? '';
  }
  // ==========================================================

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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

  static List<int> _smoothWeatherCodes(List<int> codes) {
    if (codes.length < 3) return codes;
    final smooth = List<int>.from(codes);
    for (int i = 1; i < codes.length - 1; i++) {
      final prev = codes[i - 1];
      final curr = codes[i];
      final next = codes[i + 1];
      if (!_isSameWeatherGroup(prev, curr) && !_isSameWeatherGroup(curr, next)) {
        if (_isSameWeatherGroup(prev, next)) {
          smooth[i] = prev;
        } else {
          final diffPrev = (curr - prev).abs();
          final diffNext = (curr - next).abs();
          smooth[i] = diffPrev < diffNext ? prev : next;
        }
      }
    }
    return smooth;
  }

  static bool _isSameWeatherGroup(int a, int b) {
    const groups = [
      [0, 1, 2, 3],
      [45, 48],
      [51, 53, 55, 56, 57],
      [61, 63, 65, 66, 67],
      [71, 73, 75, 77],
      [80, 81, 82],
      [85, 86],
      [95, 96, 99],
    ];
    for (final group in groups) {
      if (group.contains(a) && group.contains(b)) {
        return true;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> _fetchWithModel(
    double lat,
    double lon,
    String model,
  ) async {
    final response = await http.get(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$lat&longitude=$lon'
        '&models=$model'
        '&current=apparent_temperature,temperature_2m,relativehumidity_2m,'
        'windspeed_10m,winddirection_10m,pressure_msl,weathercode,visibility'
        '&wind_speed_unit=ms'
        '&hourly=temperature_2m,relativehumidity_2m,windspeed_10m,winddirection_10m,'
        'pressure_msl,weathercode,visibility,apparent_temperature'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min,'
        'sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,'
        'windspeed_10m_max,winddirection_10m_dominant'
        '&timezone=auto'
        '&forecast_days=7'
        '&past_days=0',
      ),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Open-Meteo returned status ${response.statusCode} for model $model');
    }
    return json.decode(response.body);
  }

  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<GeocodingResult?> _reverseGeocodeOpenCage(
    double lat,
    double lon,
    LocaleManager localeManager,
  ) async {
    final apiKey = _openCageApiKey;
    if (apiKey.isEmpty || apiKey == 'your_opencage_api_key_here') {
      debugPrint('OpenCage API key not configured');
      return null;
    }
    try {
      final languageCode = localeManager.currentLocale == 'Русский' ? 'ru' : 'en';
      final response = await http.get(
        Uri.parse(
          'https://api.opencagedata.com/geocode/v1/json?'
          'q=$lat+$lon'
          '&key=$apiKey'
          '&language=$languageCode'
          '&pretty=1'
          '&no_annotations=1',
        ),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('OpenCage error: ${response.statusCode}');
        return null;
      }
      final data = json.decode(response.body);
      if (data['results'] == null || data['results'].isEmpty) {
        debugPrint('OpenCage: no results');
        return null;
      }
      final result = data['results'][0];
      final components = result['components'] ?? {};
      final city = components['city'] ??
          components['town'] ??
          components['village'] ??
          components['municipality'] ??
          '';
      final district = components['suburb'] ??
          components['neighbourhood'] ??
          components['city_district'] ??
          components['county'] ??
          '';
      final road = components['road'] ?? components['pedestrian'] ?? '';
      final houseNumber = components['house_number'] ?? '';
      final street = road.isNotEmpty
          ? (houseNumber.isNotEmpty ? '$road, $houseNumber' : road)
          : '';
      final fullAddress = result['formatted'] ?? '';
      return GeocodingResult(
        city: city,
        district: district,
        street: street,
        fullAddress: fullAddress,
        source: 'opencage',
      );
    } catch (e) {
      debugPrint('OpenCage error: $e');
      return null;
    }
  }

  static Future<GeocodingResult> getLocationDetails(
    double lat,
    double lon,
    LocaleManager localeManager,
  ) async {
    final openCageResult = await _reverseGeocodeOpenCage(lat, lon, localeManager);
    if (openCageResult != null) {
      return openCageResult;
    }
    final coordString = '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
    return GeocodingResult(
      city: '',
      district: '',
      street: '',
      fullAddress: coordString,
      source: 'coordinates',
    );
  }

  static Future<Map<String, dynamic>> fetchAllFromOpenMeteo(
    double lat,
    double lon,
  ) async {
    debugPrint('Open-Meteo request: $lat, $lon');
    final preferredModel = _selectModel(lat, lon);
    debugPrint('Selected model: $preferredModel');
    final modelsToTry = [
      preferredModel,
      'gfs_seamless',
    ];
    Exception? lastError;
    Map<String, dynamic>? result;
    for (final model in modelsToTry) {
      try {
        final data = await _fetchWithModel(lat, lon, model);
        if (data.isNotEmpty) {
          debugPrint('Success with model: $model');
          result = data;
          break;
        }
      } catch (e) {
        debugPrint('Model $model failed: $e');
        lastError = e as Exception?;
      }
    }
    if (result == null) {
      debugPrint('All weather models unavailable');
      throw lastError ?? Exception('All weather models unavailable');
    }
    try {
      final airQualityResponse = await http.get(
        Uri.parse(
          'https://air-quality-api.open-meteo.com/v1/air-quality?'
          'latitude=$lat&longitude=$lon'
          '&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone'
          '&timezone=auto'
          '&forecast_days=1'
          '&past_days=0',
        ),
      ).timeout(const Duration(seconds: 15));
      Map<String, dynamic> airQualityData;
      if (airQualityResponse.statusCode == 200) {
        airQualityData = _normalizeAirQuality(
          json.decode(airQualityResponse.body),
        );
      } else {
        airQualityData = _getAirQualityFallback();
      }
      debugPrint('Open-Meteo processed successfully');
      return {
        'weather': _normalizeWeather(result),
        'forecast': _normalizeForecast(result),
        'airQuality': airQualityData,
        'sunData': _normalizeSunData(result),
        'extraMetrics': _normalizeExtraMetrics(result),
      };
    } catch (e) {
      debugPrint('Parse error: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _normalizeWeather(Map<String, dynamic> data) {
    final localeManager = LocaleManager();
    final current = data['current'] ?? {};
    final daily = data['daily'] ?? {};
    final double temp = _toDouble(current['temperature_2m']);
    final double apparentTemp = _toDouble(current['apparent_temperature']);
    final int humidity = _toInt(current['relativehumidity_2m']);
    final double pressure = _toDouble(current['pressure_msl'] ?? 1013.0);
    final double windSpeed = _toDouble(current['windspeed_10m']);
    final int windDeg = _toInt(current['winddirection_10m']);
    final int weatherCode = _toInt(current['weathercode']);
    final int visibility = _toInt(current['visibility'] ?? 10000);
    final double uvIndex = daily['uv_index_max']?.isNotEmpty == true
        ? _toDouble(daily['uv_index_max'][0])
        : 0.0;
    final double precipSum = daily['precipitation_sum']?.isNotEmpty == true
        ? _toDouble(daily['precipitation_sum'][0])
        : 0.0;
    final int precipProb = daily['precipitation_probability_max']?.isNotEmpty == true
        ? (daily['precipitation_probability_max'][0] as num).toInt()
        : 0;
    return {
      'name': localeManager.getText('current_location'),
      'coord': {'lat': 0, 'lon': 0},
      'main': {
        'temp': temp,
        'feels_like': apparentTemp,
        'temp_min': daily['temperature_2m_min']?.isNotEmpty == true
            ? _toDouble(daily['temperature_2m_min'][0])
            : 0.0,
        'temp_max': daily['temperature_2m_max']?.isNotEmpty == true
            ? _toDouble(daily['temperature_2m_max'][0])
            : 0.0,
        'humidity': humidity,
        'pressure': pressure,
      },
      'wind': {
        'speed': windSpeed,
        'deg': windDeg,
        'gust': null,
      },
      'weather': [
        {
          'description': _getWeatherDescription(weatherCode, localeManager),
          'icon': _getWeatherIcon(weatherCode),
          'main': _getWeatherMain(weatherCode),
        }
      ],
      'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'timezone': 0,
      'id': 0,
      'cod': 200,
      'visibility': visibility,
      'clouds': {'all': 0},
      '_extra': {
        'uvIndex': uvIndex,
        'precipitationSum': precipSum,
        'precipitationProbability': precipProb,
      },
    };
  }

  static Map<String, dynamic> _normalizeForecast(Map<String, dynamic> data) {
    final hourly = data['hourly'] ?? {};
    final times = hourly['time'] as List?;
    final rawWeatherCodes = (hourly['weathercode'] as List?)
        ?.map((e) => (e as num).toInt())
        .toList() ?? [];
    final smoothCodes = _smoothWeatherCodes(rawWeatherCodes);
    if (rawWeatherCodes.isNotEmpty && smoothCodes.isNotEmpty) {
      debugPrint('Weather code smoothing:');
      debugPrint('  Before: ${rawWeatherCodes.take(12).join(', ')}...');
      debugPrint('  After: ${smoothCodes.take(12).join(', ')}...');
    }
    final forecastList = <Map<String, dynamic>>[];
    if (times != null) {
      final now = DateTime.now();
      int startIndex = 0;
      for (int i = 0; i < times.length; i++) {
        try {
          final time = DateTime.parse(times[i]);
          if (time.hour > now.hour || (time.hour == now.hour && time.minute > now.minute)) {
            startIndex = i;
            break;
          }
        } catch (_) {}
      }
      if (startIndex + 8 > times.length) {
        startIndex = times.length - 8;
        if (startIndex < 0) startIndex = 0;
      }
      final int maxHours = 24;
      final int endIndexCalc = (startIndex + maxHours < times.length)
          ? startIndex + maxHours
          : times.length;
      for (int i = startIndex; i < endIndexCalc && i < times.length; i++) {
        final dtTxt = times[i];
        final temp = _toDouble(hourly['temperature_2m']?[i] ?? 0);
        final feelsLike = _toDouble(hourly['apparent_temperature']?[i] ?? temp);
        final humidity = (hourly['relativehumidity_2m']?[i] as num?)?.toInt() ?? 0;
        final pressure = _toDouble(hourly['pressure_msl']?[i] ?? 1013);
        final windSpeed = _toDouble(hourly['windspeed_10m']?[i] ?? 0);
        final windDeg = _toInt(hourly['winddirection_10m']?[i] ?? 0);
        final weatherCode = i < smoothCodes.length
            ? smoothCodes[i]
            : (hourly['weathercode']?[i] as num?)?.toInt() ?? 0;
        forecastList.add({
          'dt_txt': dtTxt,
          'main': {
            'temp': temp,
            'feels_like': feelsLike,
            'humidity': humidity,
            'pressure': pressure,
          },
          'weather': [
            {
              'description': _getWeatherDescription(weatherCode, LocaleManager()),
              'icon': _getWeatherIcon(weatherCode),
              'main': _getWeatherMain(weatherCode),
            }
          ],
          'wind': {
            'speed': windSpeed,
            'deg': windDeg,
          },
          'clouds': {'all': 0},
          'visibility': 10000,
          'pop': 0.0,
          'dt': 0,
        });
      }
    }
    return {'list': forecastList};
  }

  static Map<String, dynamic> _normalizeAirQuality(Map<String, dynamic> data) {
    final hourly = data['hourly'] ?? {};
    final times = hourly['time'] as List?;
    final pm25 = hourly['pm2_5'] as List?;
    final pm10 = hourly['pm10'] as List?;
    final co = hourly['carbon_monoxide'] as List?;
    final no2 = hourly['nitrogen_dioxide'] as List?;
    final so2 = hourly['sulphur_dioxide'] as List?;
    final o3 = hourly['ozone'] as List?;
    int currentIndex = 0;
    if (times != null && times.isNotEmpty) {
      final now = DateTime.now();
      for (int i = 0; i < times.length; i++) {
        try {
          final time = DateTime.parse(times[i]);
          if (time.hour <= now.hour || i == times.length - 1) {
            currentIndex = i;
          }
          if (time.hour > now.hour) break;
        } catch (_) {}
      }
    }
    double getValue(List? list, int index) {
      if (list == null || index >= list.length) return 0.0;
      final val = list[index];
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return 0.0;
    }
    final pm25Val = getValue(pm25, currentIndex);
    final pm10Val = getValue(pm10, currentIndex);
    final coVal = getValue(co, currentIndex);
    final no2Val = getValue(no2, currentIndex);
    final so2Val = getValue(so2, currentIndex);
    final o3Val = getValue(o3, currentIndex);
    int aqi = _calculateAQIFromPM25(pm25Val);
    return {
      'list': [
        {
          'main': {'aqi': aqi},
          'components': {
            'pm2_5': pm25Val,
            'pm10': pm10Val,
            'co': coVal,
            'no2': no2Val,
            'so2': so2Val,
            'o3': o3Val,
            'nh3': 0.0,
          }
        }
      ]
    };
  }

  static int _calculateAQIFromPM25(double pm25) {
    if (pm25 <= 10) return 1;
    if (pm25 <= 25) return 2;
    if (pm25 <= 50) return 3;
    if (pm25 <= 75) return 4;
    return 5;
  }

  static Map<String, dynamic> _getAirQualityFallback() {
    return {
      'list': [
        {
          'main': {'aqi': 2},
          'components': {
            'pm2_5': 0.0,
            'pm10': 0.0,
            'co': 0.0,
            'no2': 0.0,
            'so2': 0.0,
            'o3': 0.0,
            'nh3': 0.0,
          }
        }
      ]
    };
  }

  static Map<String, dynamic> _normalizeSunData(Map<String, dynamic> data) {
    try {
      final daily = data['daily'] ?? {};
      DateTime? sunrise;
      DateTime? sunset;
      if (daily['sunrise']?.isNotEmpty == true) {
        sunrise = DateTime.tryParse(daily['sunrise'][0]);
      }
      if (daily['sunset']?.isNotEmpty == true) {
        sunset = DateTime.tryParse(daily['sunset'][0]);
      }
      return {'sunrise': sunrise, 'sunset': sunset};
    } catch (e) {
      return {'sunrise': null, 'sunset': null};
    }
  }

  static Map<String, dynamic> _normalizeExtraMetrics(Map<String, dynamic> data) {
    try {
      final daily = data['daily'] ?? {};
      final hourly = data['hourly'] ?? {};
      final now = DateTime.now();
      int currentHourIndex = 0;
      if (hourly['time'] != null && hourly['time'] is List) {
        final times = hourly['time'] as List;
        for (int i = 0; i < times.length; i++) {
          try {
            final time = DateTime.parse(times[i]);
            if (time.hour <= now.hour || i == times.length - 1) {
              currentHourIndex = i;
            }
            if (time.hour > now.hour) break;
          } catch (_) {}
        }
      }
      double? dewPoint;
      if (hourly['temperature_2m'] != null &&
          hourly['relativehumidity_2m'] != null &&
          hourly['temperature_2m'] is List &&
          hourly['relativehumidity_2m'] is List) {
        final tempList = hourly['temperature_2m'] as List;
        final humidityList = hourly['relativehumidity_2m'] as List;
        if (currentHourIndex < tempList.length && currentHourIndex < humidityList.length) {
          final temp = _toDouble(tempList[currentHourIndex]);
          final humidity = _toDouble(humidityList[currentHourIndex]);
          if (temp != 0 && humidity > 0) {
            const a = 17.27;
            const b = 237.7;
            final alpha = (a * temp) / (b + temp) + log(humidity / 100);
            dewPoint = (b * alpha) / (a - alpha);
          }
        }
      }
      double? uvIndex;
      if (daily['uv_index_max']?.isNotEmpty == true) {
        uvIndex = _toDouble(daily['uv_index_max'][0]);
      }
      double? visibility;
      if (hourly['visibility'] != null && hourly['visibility'] is List) {
        final visibilityList = hourly['visibility'] as List;
        if (currentHourIndex < visibilityList.length) {
          final val = _toDouble(visibilityList[currentHourIndex]);
          if (val > 0) visibility = val;
        }
      }
      int? precipProb;
      if (daily['precipitation_probability_max']?.isNotEmpty == true) {
        precipProb = (daily['precipitation_probability_max'][0] as num).toInt();
      }
      return {
        'dewPoint': dewPoint,
        'visibility': visibility,
        'uvIndex': uvIndex,
        'precipitationProbability': precipProb,
        'shortwaveRadiation': null,
      };
    } catch (e) {
      return {
        'dewPoint': null,
        'visibility': null,
        'uvIndex': null,
        'precipitationProbability': null,
        'shortwaveRadiation': null,
      };
    }
  }

  static Future<WeatherResponse> fetchAllWeatherData(
    double lat,
    double lon,
  ) async {
    final localeManager = LocaleManager();
    try {
      final data = await fetchAllFromOpenMeteo(lat, lon);
      final locationDetails = await getLocationDetails(lat, lon, localeManager);
      return WeatherResponse(
        weather: data['weather'] as Map<String, dynamic>,
        forecast: data['forecast'] as Map<String, dynamic>,
        airQuality: data['airQuality'] as Map<String, dynamic>,
        sunData: data['sunData'] as Map<String, dynamic>,
        source: WeatherSource.openMeteo,
        locationDetails: locationDetails.toMap(),
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

  static String _getWeatherDescription(int code, LocaleManager localeManager) {
    const descriptions = {
      0: 'clear_sky',
      1: 'mostly_clear',
      2: 'partly_cloudy',
      3: 'overcast',
      45: 'fog',
      48: 'freezing_fog',
      51: 'light_drizzle',
      53: 'moderate_drizzle',
      55: 'heavy_drizzle',
      56: 'light_freezing_drizzle',
      57: 'heavy_freezing_drizzle',
      61: 'light_rain',
      63: 'moderate_rain',
      65: 'heavy_rain',
      66: 'light_freezing_rain',
      67: 'heavy_freezing_rain',
      71: 'light_snow',
      73: 'moderate_snow',
      75: 'heavy_snow',
      77: 'snow_grains',
      80: 'light_shower',
      81: 'moderate_shower',
      82: 'heavy_shower',
      85: 'light_snow_shower',
      86: 'heavy_snow_shower',
      95: 'thunderstorm',
      96: 'thunderstorm_hail',
      99: 'heavy_thunderstorm',
    };
    final key = descriptions[code] ?? 'unknown';
    return localeManager.getText(key);
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
}

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