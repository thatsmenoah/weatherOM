import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shake/shake.dart';
import 'package:http/http.dart' as http;
import '../core/data_system.dart';
import '../core/tips_system.dart';
import '../core/loading_system.dart';
import '../widgets/loading_widgets.dart';
import '../services/weather_service.dart';
import '../services/weather_normalizer.dart';
import '../utils/weather_utils.dart';
import '../utils/map_utils.dart';
import '../constants/weather_const.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/compact_weather_header.dart';
import '../widgets/weather_forecast_widgets.dart';
import '../widgets/weather_main_card.dart';
import '../widgets/weather_screen_widgets.dart';
import '../widgets/weather_conditions_widgets.dart';
import '../widgets/move_sun.dart';
import '../core/locale_manager.dart';
import '../widgets/error_dialog.dart';

// ============================================================
// РћРЎРќРћР’РќРћР™ Р­РљР РђРќ РџРћР“РћР”Р«
// ============================================================

class WeatherScreen extends StatefulWidget {
  final GlobalKey? tipsKey;

  const WeatherScreen({super.key, this.tipsKey});

  @override
  State<WeatherScreen> createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen>
  with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final LocaleManager _localeManager = LocaleManager();

  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? forecastData;
  Map<String, dynamic>? airQualityData;
  Map<String, dynamic>? sunData;
  Map<String, dynamic>? locationDetails;
  String cityName = 'Р—Р°РіСЂСѓР·РєР°...';
  String displayLocation = 'Р—Р°РіСЂСѓР·РєР°...';

  String locationText = 'Р—Р°РіСЂСѓР·РєР°...';
  String? subLocationText;

  double? lat;
  double? lon;
  double? get currentLat => lat;
  double? get currentLon => lon;
  String get currentCityName => cityName;

  // Р РµР°Р»СЊРЅС‹Рµ РєРѕРѕСЂРґРёРЅР°С‚С‹ СѓСЃС‚СЂРѕР№СЃС‚РІР°. РћРЅРё РЅРµ РјРµРЅСЏСЋС‚СЃСЏ РїСЂРё СЂСѓС‡РЅРѕРј РІС‹Р±РѕСЂРµ РіРѕСЂРѕРґР°,
  // РїРѕСЌС‚РѕРјСѓ РїРѕ РЅРёРј РІСЃРµРіРґР° РјРѕР¶РЅРѕ РІРµСЂРЅСѓС‚СЊСЃСЏ Рє РїРѕРіРѕРґРµ "Сѓ СЃРµР±СЏ РЅР° СЂР°Р№РѕРЅРµ".
  double? _deviceLat;
  double? _deviceLon;
  String? _deviceLocationName;

  double? get deviceLat => _deviceLat;
  double? get deviceLon => _deviceLon;
  String? get deviceLocationName => _deviceLocationName;

  final GlobalKey _tipsKey = GlobalKey();
  final GlobalKey<MoveSunState> _moveSunKey = GlobalKey<MoveSunState>();
  final ScrollController _scrollController = ScrollController();

  final DataSystem _dataSystem = DataSystem();
  final TipsSystem _tipsSystem = TipsSystem();
  final LoadingStateManager _loadingManager = LoadingStateManager();
  late final ShakeDetector _shakeDetector;

  /// РљР»РёРµРЅС‚ С‚РµРєСѓС‰РµРіРѕ СЃРµС‚РµРІРѕРіРѕ Р·Р°РїСЂРѕСЃР°: С‡РµСЂРµР· close() РѕРЅ РѕР±СЂС‹РІР°РµС‚СЃСЏ.
  http.Client? _activeRequestClient;

  bool _showStatusToast = false;
  bool _showCompactHeader = false;
  bool _isUsingFallbackLocation = false;
  bool _isLocationManuallySelected = false;
  bool _shakeRefreshEnabled = true;
  bool _isShakeDetectorListening = false;
  bool _isRefreshInProgress = false;

  Map<String, dynamic>? _cachedTip;
  bool _isInitialized = false;
  int _weatherRequestId = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _supportsShakeDetection =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeDetector = ShakeDetector.waitForStart(
      onPhoneShake: (_) {
        if (!_shakeRefreshEnabled ||
            !mounted ||
            weatherData == null ||
            _loadingManager.isLoading ||
            _isRefreshInProgress) {
          return;
        }
        _refreshWeather();
      },
      shakeThresholdGravity: 2.7,
      shakeSlopTimeMS: 900,
      shakeCountResetTime: 1800,
      minimumShakeCount: 2,
      useFilter: true,
    );
    _startShakeDetector();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_shakeRefreshEnabled) _startShakeDetector();
    } else {
      _stopShakeDetector();
    }
  }

  void _startShakeDetector() {
    if (!_supportsShakeDetection || _isShakeDetectorListening) return;
    _shakeDetector.startListening();
    _isShakeDetectorListening = true;
  }

  void _stopShakeDetector() {
    if (!_isShakeDetectorListening) return;
    _shakeDetector.stopListening();
    _isShakeDetectorListening = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeApp();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopShakeDetector();
    _abortActiveRequest();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrollOffset = _scrollController.offset;
    if (scrollOffset > WeatherConst.scrollThreshold && !_showCompactHeader) {
      setState(() => _showCompactHeader = true);
    } else if (scrollOffset <= WeatherConst.scrollThreshold &&
        _showCompactHeader) {
      setState(() => _showCompactHeader = false);
    }
  }

  void _updateTip() {
    if (weatherData != null) {
      _cachedTip = _tipsSystem.analyzeWeatherForTips(
        weatherData,
        forecastData,
        sunData,
      );
    }
  }

  void _updateLocationText() {
    if (locationDetails != null) {
      final geoResult = GeocodingResult.fromMap(locationDetails!);

      if (geoResult.district.isNotEmpty) {
        locationText = geoResult.district;
        if (geoResult.city.isNotEmpty && geoResult.city != geoResult.district) {
          subLocationText = geoResult.city;
        } else {
          subLocationText = null;
        }
      } else if (geoResult.city.isNotEmpty) {
        locationText = geoResult.city;
        subLocationText = null;
      } else {
        locationText = displayLocation;
        subLocationText = null;
      }
    } else {
      locationText = displayLocation;
      subLocationText = null;
    }
  }

  Future<void> _initializeApp() async {
    final requestId = ++_weatherRequestId;
    try {
      await _dataSystem.init();
      if (!mounted || requestId != _weatherRequestId) return;
      debugPrint('DataSystem РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');

      // Р Р°РЅСЊС€Рµ С‡С‚РµРЅРёРµ РєРµС€Р° С€Р»Рѕ Р±РµР· try/catch, Рё РѕРґРёРЅ Р±РёС‚С‹Р№ С„Р°Р№Р» РѕСЃС‚Р°РІР»СЏР» СЌРєСЂР°РЅ
      // РЅР°РІСЃРµРіРґР° РЅР° СЃРїРёРЅРЅРµСЂРµ: РЅРё РѕС€РёР±РєРё, РЅРё РєРЅРѕРїРєРё В«РџРѕРІС‚РѕСЂРёС‚СЊВ».
      _loadAllFromStorage();

      if (weatherData == null) {
        _loadingManager.startLoading();
      }
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      debugPrint('_initializeApp: РЅРµ СѓРґР°Р»РѕСЃСЊ РїСЂРѕС‡РёС‚Р°С‚СЊ РєРµС€ - $e\n$stackTrace');
      if (!mounted) return;
      _loadingManager.setError(_localeManager.getText('error'));
      if (mounted) setState(() {});
      return;
    }
    await _updateWeatherInBackground();
  }

  Future<void> _updateWeatherInBackground() async {
    final requestId = ++_weatherRequestId;
    try {
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        if (!mounted || requestId != _weatherRequestId) return;
        lat = position.latitude;
        lon = position.longitude;
        _deviceLat = position.latitude;
        _deviceLon = position.longitude;
        _isLocationManuallySelected = false;
      }
    } catch (e) {
      debugPrint('_updateWeatherInBackground: GPS РЅРµРґРѕСЃС‚СѓРїРµРЅ - $e');
      if (!mounted || requestId != _weatherRequestId) return;

      // Р”РёР°Р»РѕРі РїРѕРєР°Р·С‹РІР°РµРј С‚РѕР»СЊРєРѕ РєРѕРіРґР° РїРѕРєР°Р·Р°С‚СЊ РЅРµС‡РµРіРѕ: РїСЂРё Р¶РёРІРѕРј РєРµС€Рµ
      // РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РїСЂРѕСЃС‚Рѕ СѓРІРёРґРёС‚ РґР°РЅРЅС‹Рµ Рё С‚РѕСЃС‚.
      if (weatherData == null) {
        await showLocationErrorDialog(context);
      }

      // Р”РµРјРѕ-РєРѕРѕСЂРґРёРЅР°С‚С‹ вЂ” С‚РѕР»СЊРєРѕ РµСЃР»Рё СЃРІРѕРёС… РІРѕРѕР±С‰Рµ РЅРµС‚.
      final hasCoordinates = lat != null && lon != null;
      lat ??= 55.7558;
      lon ??= 37.6173;
      _isUsingFallbackLocation = !hasCoordinates;
      _isLocationManuallySelected = false;
    }
    if (!mounted || requestId != _weatherRequestId) return;
    await _fetchFreshData();
  }

  Future<void> _saveToStorage() async {
    debugPrint(
      'РЎРѕС…СЂР°РЅСЏСЋ РІ РєРµС€: weather=${weatherData != null}, forecast=${forecastData != null}',
    );
    await _dataSystem.saveToCache(
      weatherData: weatherData,
      forecastData: forecastData,
      airQualityData: airQualityData,
      sunData: sunData,
      cityName: cityName,
      lat: lat,
      lon: lon,
      locationDetails: locationDetails,
      isLocationManuallySelected: _isLocationManuallySelected,
    );
  }

  Future<void> _fetchFreshData() async {
    final requestId = ++_weatherRequestId;
    final requestLat = lat;
    final requestLon = lon;
    if (requestLat == null || requestLon == null) return;

    // РќРѕРІС‹Р№ Р·Р°РїСЂРѕСЃ РѕС‚РјРµРЅСЏРµС‚ РїСЂРµРґС‹РґСѓС‰РёР№: Р·Р°РєСЂС‹С‚РёРµ РєР»РёРµРЅС‚Р° РѕР±СЂС‹РІР°РµС‚ СѓР¶Рµ
    // РѕС‚РїСЂР°РІР»РµРЅРЅС‹Р№ HTTP-Р·Р°РїСЂРѕСЃ, Р° РЅРµ РґР°С‘С‚ РµРјСѓ Р·СЂСЏ РєР°С‡Р°С‚СЊ РґР°РЅРЅС‹Рµ РІ С„РѕРЅ.
    _abortActiveRequest();
    final client = http.Client();
    _activeRequestClient = client;

    try {
      final response = await WeatherService.fetchAllWeatherData(
        requestLat,
        requestLon,
        client: client,
      );

      if (!mounted || requestId != _weatherRequestId) return;

      if (response.hasError) {
        final error = response.errorMessage ?? '';
        debugPrint('_fetchFreshData: СЃРµСЂРІРёСЃ РѕС‚РІРµС‚РёР» РѕС€РёР±РєРѕР№ - $error');
        final isOffline = _isOfflineMessage(error);

        if (weatherData != null) {
          setState(() => _showStatusToast = true);
          if (isOffline) {
            _loadingManager.setOfflineMode();
          } else {
            _loadingManager.setError(_localeManager.getText('update_failed'));
          }
        } else {
          if (isOffline) {
            _loadingManager.setError(_localeManager.getText('no_internet'));
          } else {
            _loadingManager.setError(_localeManager.getText('error'));
          }
          if (mounted) setState(() {});
        }
        return;
      }

      setState(() {
        weatherData = response.weather;
        forecastData = response.forecast;
        airQualityData = response.airQuality;
        sunData = response.sunData;
        locationDetails = response.locationDetails;
        _isUsingFallbackLocation = false;
        _updateDisplayLocation(response);
        _updateLocationText();
        cityName =
            response.weather['name'] ??
            _localeManager.getText('current_location');
        _showStatusToast = false;
      });

      // РџРѕРёСЃРє РїРѕРєР°Р·С‹РІР°РµС‚ Р°РєС‚СѓР°Р»СЊРЅСѓСЋ Р»РѕРєР°С†РёСЋ РІ РѕС‚РґРµР»СЊРЅРѕР№ СЃРµРєС†РёРё, РґР°Р¶Рµ РµСЃР»Рё
      // РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ СѓС€С‘Р» РІ РґСЂСѓРіРѕР№ РіРѕСЂРѕРґ вЂ” Р·Р°РїРѕРјРёРЅР°РµРј РµС‘ РЅР°Р·РІР°РЅРёРµ.
      if (!_isLocationManuallySelected) {
        _deviceLocationName = locationText;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveSunKey.currentState?.updatePosition();
      });

      _loadingManager.finishLoading(fromStorage: false);
      _loadingManager.setCacheTimestamp(DateTime.now());

      _updateTip();
      await _saveToStorage();
    } catch (e, stackTrace) {
      debugPrint('_fetchFreshData: Р·Р°РїСЂРѕСЃ СѓРїР°Р» - $e\n$stackTrace');
      if (!mounted || requestId != _weatherRequestId) return;
      final isNetworkIssue = _isNetworkError(e);
      if (weatherData != null) {
        setState(() => _showStatusToast = true);
        if (isNetworkIssue) {
          _loadingManager.setOfflineMode();
        } else {
          _loadingManager.setError(_localeManager.getText('update_failed'));
        }
      } else {
        _loadingManager.setError(
          _localeManager.getText(
            isNetworkIssue ? 'no_internet' : 'error',
          ),
        );
        if (mounted) setState(() {});
      }
    } finally {
      // РљР»РёРµРЅС‚ Р¶РёРІС‘С‚ С‚РѕР»СЊРєРѕ РЅР° РІСЂРµРјСЏ РѕРґРЅРѕРіРѕ Р·Р°РїСЂРѕСЃР°.
      if (identical(_activeRequestClient, client)) {
        _activeRequestClient = null;
      }
      client.close();
    }
  }

  /// РћР±СЂС‹РІР°РµС‚ С‚РµРєСѓС‰РёР№ СЃРµС‚РµРІРѕР№ Р·Р°РїСЂРѕСЃ, РµСЃР»Рё РѕРЅ РµС‰С‘ РёРґС‘С‚.
  void _abortActiveRequest() {
    final client = _activeRequestClient;
    _activeRequestClient = null;
    client?.close();
  }

  /// Р Р°РЅСЊС€Рµ СЌС‚Рѕ РѕРїСЂРµРґРµР»СЏР»РѕСЃСЊ СЃС‚СЂРѕРєР°РјРё РІРёРґР° `e.toString().contains(...)` РІ С‡РµС‚С‹СЂС‘С…
  /// РјРµСЃС‚Р°С…. РћС€РёР±РєРё http Р¶РёРІСѓС‚ РІ [http.ClientException], С‚Р°Р№РјР°СѓС‚С‹ вЂ” РІ
  /// [TimeoutException], РІСЃС‘ РѕСЃС‚Р°Р»СЊРЅРѕРµ вЂ” РѕР±СЂС‹РІ СЃРµС‚Рё.
  bool _isNetworkError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }
    return error.toString().contains('SocketException');
  }

  /// РўРѕС‚ Р¶Рµ СЂР°Р·Р±РѕСЂ РґР»СЏ СЃС‚СЂРѕРєРё, РєРѕС‚РѕСЂСѓСЋ РІРµСЂРЅСѓР» СЃРµСЂРІРёСЃ.
  bool _isOfflineMessage(String message) {
    return message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('TimeoutException') ||
        message.contains('HandshakeException') ||
        message.contains('Connection refused');
  }

  void _updateDisplayLocation(WeatherResponse response) {
    if (response.locationDetails != null) {
      final details = response.locationDetails!;
      final geoResult = GeocodingResult.fromMap(details);
      displayLocation = geoResult.displayName.isNotEmpty
          ? geoResult.displayName
          : cityName;
    } else {
      displayLocation = cityName;
    }
  }

  void _loadAllFromStorage() {
    final allData = _dataSystem.getValidCache();
    debugPrint('Р—Р°РіСЂСѓР¶Р°СЋ РёР· РєРµС€Р° (РІР°Р»РёРґРЅС‹Р№): data=${allData != null}');

    if (allData != null) {
      debugPrint('weather СЃРѕРґРµСЂР¶РёС‚ РєР»СЋС‡Рё: ${allData['weather']?.keys}');
      debugPrint('forecast СЃРѕРґРµСЂР¶РёС‚ РєР»СЋС‡Рё: ${allData['forecast']?.keys}');

      setState(() {
        weatherData = asMap(allData['weather']);
        forecastData = asMap(allData['forecast']);
        airQualityData = asMap(allData['airQuality']);
        sunData = asMap(allData['sunData']);
        cityName = allData['city'] ?? _localeManager.getText('loading');
        locationDetails = asMap(allData['locationDetails']);
        _isLocationManuallySelected =
            allData['isLocationManuallySelected'] == true;

        // Р Р°РЅСЊС€Рµ Р·РґРµСЃСЊ СЃС‚РѕСЏР»Рѕ `as double?`: JSON-С‡РёСЃР»Рѕ Р±РµР· РґСЂРѕР±РЅРѕР№ С‡Р°СЃС‚Рё
        // СЂР°Р·Р±РёСЂР°РµС‚СЃСЏ РєР°Рє int, Рё РєРµС€ СЂРѕРЅСЏР» СЌРєСЂР°РЅ С†РµР»РёРєРѕРј.
        lat = WeatherNormalizer.toDouble(allData['lat']);
        lon = WeatherNormalizer.toDouble(allData['lon']);
      });

      if (locationDetails != null) {
        final geoResult = GeocodingResult.fromMap(locationDetails!);
        displayLocation = geoResult.displayName.isNotEmpty
            ? geoResult.displayName
            : cityName;
        _updateLocationText();
      } else {
        displayLocation = cityName;
        locationText = cityName;
        subLocationText = null;
      }

      // Р•СЃР»Рё РІ РєРµС€Рµ Р»РµР¶РёС‚ РїРѕРіРѕРґР° "Сѓ СЃРµР±СЏ РЅР° СЂР°Р№РѕРЅРµ", Р·РЅР°С‡РёС‚ СЌС‚Рё РєРѕРѕСЂРґРёРЅР°С‚С‹ вЂ”
      // Р°РєС‚СѓР°Р»СЊРЅР°СЏ Р»РѕРєР°С†РёСЏ СѓСЃС‚СЂРѕР№СЃС‚РІР°, Р° РЅРµ СЂРµР·СѓР»СЊС‚Р°С‚ СЂСѓС‡РЅРѕРіРѕ РїРѕРёСЃРєР°.
      if (!_isLocationManuallySelected && lat != null && lon != null) {
        _deviceLat = lat;
        _deviceLon = lon;
        _deviceLocationName = locationText;
      }

      _updateTip();

        final timestamp = allData['timestamp'];
      if (timestamp != null && mounted) {
        try {
          final cacheTime = DateTime.tryParse(timestamp.toString());
          if (cacheTime != null) {
            _loadingManager.setCacheTimestamp(cacheTime);
          }
          _loadingManager.finishLoading(fromStorage: true);
        } catch (e) {
          debugPrint('_loadAllFromStorage: Р±РёС‚Р°СЏ РјРµС‚РєР° РІСЂРµРјРµРЅРё РІ РєРµС€Рµ - $e');
          _loadingManager.finishLoading(fromStorage: true);
        }
      } else {
        _loadingManager.finishLoading(fromStorage: true);
      }

      if (mounted) {
        debugPrint('РћР±РЅРѕРІР»СЏСЋ UI РёР· РІР°Р»РёРґРЅРѕРіРѕ РєРµС€Р°');
        setState(() {});
      }
    } else {
      debugPrint('Р’Р°Р»РёРґРЅС‹Р№ РєРµС€ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚');
      _loadingManager.startLoading();
      if (mounted) setState(() {});
    }
  }

  Future<void> setLocation(
    double newLat,
    double newLon,
    String newCityName,
  ) async {
    setState(() {
      lat = newLat;
      lon = newLon;
      cityName = newCityName;
      displayLocation = newCityName;
      locationText = newCityName;
      subLocationText = null;
      _isUsingFallbackLocation = false;
      _isLocationManuallySelected = true;
      _showStatusToast = false;
    });
    _loadingManager.startLoading();
    if (mounted) setState(() {});
    _isRefreshInProgress = true;
    try {
      await _fetchFreshData();
    } finally {
      _isRefreshInProgress = false;
    }
  }

  /// Р’РѕР·РІСЂР°С‰Р°РµС‚ РїРѕРіРѕРґСѓ Рє С‚РµРєСѓС‰РµРјСѓ РјРµСЃС‚РѕРїРѕР»РѕР¶РµРЅРёСЋ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ.
  /// Р’РѕР·РІСЂР°С‰Р°РµС‚ РєРѕРѕСЂРґРёРЅР°С‚С‹, РїРѕ РєРѕС‚РѕСЂС‹Рј СЂРµР°Р»СЊРЅРѕ СЃС‡РёС‚Р°РµС‚СЃСЏ РїСЂРѕРіРЅРѕР·, Р»РёР±Рѕ null,
  /// РµСЃР»Рё РјРµСЃС‚РѕРїРѕР»РѕР¶РµРЅРёРµ РѕРїСЂРµРґРµР»РёС‚СЊ РЅРµ СѓРґР°Р»РѕСЃСЊ Рё РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РѕСЃС‚Р°С‘С‚СЃСЏ С‚Р°Рј,
  /// РіРґРµ Р±С‹Р».
  Future<(double, double)?> useCurrentLocation() async {
    final requestId = ++_weatherRequestId;
    var targetLat = _deviceLat;
    var targetLon = _deviceLon;

    try {
      final position = await WeatherService.getCurrentPosition();
      if (!mounted || requestId != _weatherRequestId) return null;
      targetLat = position.latitude;
      targetLon = position.longitude;
      _deviceLat = position.latitude;
      _deviceLon = position.longitude;
    } catch (e) {
      debugPrint('useCurrentLocation: GPS РЅРµРґРѕСЃС‚СѓРїРµРЅ - $e');
    }

    if (!mounted || requestId != _weatherRequestId) return null;

    final resolvedLat = targetLat;
    final resolvedLon = targetLon;
    if (resolvedLat == null || resolvedLon == null) {
      if (weatherData != null) {
        setState(() => _showStatusToast = true);
      } else {
        await showLocationErrorDialog(context);
      }
      return null;
    }

    setState(() {
      lat = resolvedLat;
      lon = resolvedLon;
      _isLocationManuallySelected = false;
      _isUsingFallbackLocation = false;
      _showStatusToast = false;
      locationText =
          _deviceLocationName ?? _localeManager.getText('current_location');
      subLocationText = null;
    });
    _loadingManager.startLoading();
    if (mounted) setState(() {});

    _isRefreshInProgress = true;
    try {
      await _fetchFreshData();
    } finally {
      _isRefreshInProgress = false;
    }
    return (resolvedLat, resolvedLon);
  }

  // ============================================================
  // РћР‘РќРћР’Р›Р•РќРР• РџРћР“РћР”Р«
  // ============================================================
  Future<void> _refreshWeather() async {
    if (_isRefreshInProgress || _loadingManager.isLoading) return;
    final requestId = ++_weatherRequestId;
    _isRefreshInProgress = true;
    try {
      _loadingManager.startRefreshing();
      if (mounted) setState(() {});
      if (!_isLocationManuallySelected) {
        try {
          final position = await WeatherService.getCurrentPosition();
          if (!mounted || requestId != _weatherRequestId) return;
          lat = position.latitude;
          lon = position.longitude;
          _deviceLat = position.latitude;
          _deviceLon = position.longitude;
          _isUsingFallbackLocation = false;
        } catch (e) {
          if (!mounted || requestId != _weatherRequestId) return;
          if (weatherData == null) {
            await showLocationErrorDialog(context);
            if (!mounted || requestId != _weatherRequestId) return;
          }
          lat ??= 55.7558;
          lon ??= 37.6173;
          _isUsingFallbackLocation = true;
        }
      }
      if (!mounted || requestId != _weatherRequestId) return;
      await _fetchFreshData();
      _updateTip();
      if (mounted) setState(() {});
    } finally {
      _isRefreshInProgress = false;
    }
  }

  void setShakeRefreshEnabled(bool enabled) {
    if (_shakeRefreshEnabled == enabled) return;
    _shakeRefreshEnabled = enabled;
    if (enabled) {
      _startShakeDetector();
    } else {
      _stopShakeDetector();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      decoration: const BoxDecoration(color: WeatherConst.bgScreen),
      child: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            if (weatherData != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showCompactHeader ? 1.0 : 0.0,
                  duration: WeatherConst.durHeaderAnim,
                  curve: Curves.easeInOut,
                  child: AnimatedSlide(
                    offset: _showCompactHeader
                        ? Offset.zero
                        : const Offset(0, -0.15),
                    duration: WeatherConst.durHeaderAnim,
                    curve: Curves.easeInOut,
                    child: CompactWeatherHeader(
                      cityName: locationText,
                      temp: weatherData!['main']['temp'].round(),
                      feelsLike: weatherData!['main']['feels_like'].round(),
                      iconCode: weatherData!['weather'][0]['icon'],
                      description: weatherData!['weather'][0]['description'],
                      now: DateTime.now(),
                    ),
                  ),
                ),
              ),
            if (_showStatusToast)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: StatusToast(
                      isVisible: _showStatusToast,
                      title: _loadingManager.isOffline
                          ? _localeManager.getText('offline')
                          : _localeManager.getText('update_failed'),
                      onDismiss: () => setState(() => _showStatusToast = false),
                    ),
                  ),
                ),
              ),
            if (_isUsingFallbackLocation && weatherData != null)
              Positioned(
                bottom: 90,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localeManager.getText('fallback_location'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingManager.hasError && weatherData == null) {
      return LoadingErrorWidget(
        message: _loadingManager.errorMessage,
        subtitle: null,
        onRetry: () async {
          _loadingManager.startLoading();
          if (mounted) setState(() {});
          await _initializeApp();
        },
        isOffline: _loadingManager.isOffline,
      );
    }

    if (weatherData == null && _loadingManager.isLoading) {
      return const AppLoadingOverlay();
    }

    if (weatherData != null) {
      return RefreshIndicator(
        onRefresh: _refreshWeather,
        color: Colors.white,
        backgroundColor: Colors.transparent,
        child: ScrollConfiguration(
          behavior: NoGlowBehavior(),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: WeatherConst.padScreen,
              child: Column(
                children: [
                  _buildMainWeatherCard(),
                  const SizedBox(height: 12),
                  Container(
                    key: widget.tipsKey ?? _tipsKey,
                    child: _buildTipCard(),
                  ),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    WeatherHourlyForecast(
                      forecastData: forecastData,
                      localeManager: _localeManager,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                    WeatherDailyForecast(
                      forecastData: forecastData,
                      localeManager: _localeManager,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGlassCard(_buildSunContent()),
                  const SizedBox(height: 12),
                  _buildGlassCard(_buildAirQualityContent()),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTipCard() {
    if (_cachedTip == null || _cachedTip!.isEmpty) {
      return const SizedBox.shrink();
    }

    final tip = _cachedTip!;
    final isImportant = WeatherUtils.isTipImportant(tip);

    return AnimatedTipCard(
      title: tip['title'],
      message: tip['message'],
      timeText: tip['time'],
      accentColor: tip['color'],
      icon: tip['icon'],
      isImportant: isImportant,
    );
  }

  Widget _buildMainWeatherCard() {
    if (weatherData == null) return const SizedBox.shrink();

    return WeatherMainCard(
      weatherData: weatherData!,
      locationText: locationText,
      subLocationText: subLocationText,
      localeManager: _localeManager,
      updateTime: _loadingManager.displayTime,
      isFromCache: _loadingManager.isUsingStorage,
    );
  }

  Widget _buildGlassCard(Widget child) {
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius: BorderRadius.circular(WeatherConst.radiusGlassCard),
          border: Border.all(color: WeatherConst.bgCardLighter),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WeatherConst.radiusGlassCard),
          child: Padding(
            padding: WeatherConst.padGlassCardContent,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSunContent() {
    return WeatherSunContent(
      sunData: sunData,
      localeManager: _localeManager,
      moveSunKey: _moveSunKey,
    );
  }

  Widget _buildAirQualityContent() {
    return WeatherAirQualityContent(
      airQualityData: airQualityData,
      localeManager: _localeManager,
    );
  }
}