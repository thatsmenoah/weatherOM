import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:math';
import '../services/weather_service.dart';
import '../services/weather_normalizer.dart';
import '../utils/weather_utils.dart';
import '../core/data_system.dart';
import '../core/loading_system.dart';
import '../widgets/loading_widgets.dart';
import '../core/locale_manager.dart';
import '../widgets/app_loading_indicator.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  final LocaleManager _localeManager = LocaleManager();

  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airQualityData;
  Map<String, dynamic>? extraMetrics;
  String? cityName;
  double? lat;
  double? lon;

  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasData = false;
  bool _dataSystemInitialized = false;
  bool _hasSelectedLocation = false;
  int _requestGeneration = 0;

  final DataSystem _dataSystem = DataSystem(fileName: 'activity_data.json');
  final LoadingStateManager _loadingManager = LoadingStateManager();

  final ScrollController _scrollController = ScrollController();

  /// Клиент текущего сетевого запроса: через close() он обрывается.
  http.Client? _activeRequestClient;

  @override
  void initState() {
    super.initState();
    _initDataSystem();
  }

  @override
  void dispose() {
    _abortActiveRequest();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initDataSystem() async {
    await _dataSystem.init();
    if (!mounted) return;
    _dataSystemInitialized = true;

    if (_hasSelectedLocation) {
      if (_hasData) {
        await _refreshData();
      } else {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
        _loadingManager.startLoading();
        await _fetchData();
      }
      return;
    }

    final cachedData = _dataSystem.getAllCachedData();

    if (cachedData != null && _dataSystem.isWeatherValid) {
      _applyDataFromCache(cachedData);
      _loadingManager.finishLoading(fromStorage: true);
      setState(() {
        _hasData = true;
        _isLoading = false;
      });
      _fetchDataInBackground();
    } else if (cachedData != null && !_dataSystem.isWeatherValid) {
      _applyDataFromCache(cachedData);
      _loadingManager.setOfflineMode();
      setState(() {
        _hasData = true;
        _isLoading = false;
      });
      _fetchDataInBackground();
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      _loadingManager.startLoading();
      await _getLocationAndData();
    }
  }

  void _applyDataFromCache(Map<String, dynamic> cachedData) {
    setState(() {
      weatherData = cachedData['weather'];
      airQualityData = cachedData['airQuality'];
      extraMetrics = cachedData['extraMetrics'];
      cityName = cachedData['city'];

      // `as double?` здесь ронял экран на кеше, где координаты сохранились
      // целыми числами.
      final cachedLat = cachedData['lat'];
      final cachedLon = cachedData['lon'];
      if (cachedLat != null) lat = WeatherNormalizer.toDouble(cachedLat);
      if (cachedLon != null) lon = WeatherNormalizer.toDouble(cachedLon);
    });
  }

  void setLocation(double newLat, double newLon) {
    final locationChanged = lat != newLat || lon != newLon;
    _hasSelectedLocation = true;
    if (!locationChanged) return;

    lat = newLat;
    lon = newLon;
    ++_requestGeneration;
    if (!_dataSystemInitialized) return;

    if (_hasData) {
      _refreshData();
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      _loadingManager.startLoading();
      _fetchData();
    }
  }

  /// Единственное место, где экран ходит в сеть за погодой.
  ///
  /// Раньше одинаковая последовательность «запрос → кеш → setState» была
  /// скопирована в _fetchData, _fetchDataInBackground и _refreshData, поэтому
  /// правки в одном варианте расходились с остальными.
  ///
  /// Возвращает true, если данные пришли. [silentOnError] нужен фоновым
  /// обновлениям: там ошибка не должна перетирать уже показанные данные.
  Future<bool> _loadWeather({
    bool showFullScreenLoader = false,
    bool silentOnError = false,
  }) async {
    final requestId = ++_requestGeneration;
    http.Client? client;
    if (showFullScreenLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        if (!mounted || requestId != _requestGeneration) return false;
        lat = position.latitude;
        lon = position.longitude;
      }

      _abortActiveRequest();
      client = http.Client();
      _activeRequestClient = client;

      final response = await WeatherService.fetchAllWeatherData(
        lat!,
        lon!,
        client: client,
      );

      if (!mounted || requestId != _requestGeneration || response.hasError) {
        return false;
      }

      final weather = response.weather;
      final airQuality = response.airQuality;
      final extraMetricsFromResponse = _extractExtraMetrics(
        weather,
        response.extraMetrics,
      );
      final cityNameFromData =
          weather['name'] ?? _localeManager.getText('unknown');

      await _dataSystem.saveToCache(
        weatherData: weather,
        forecastData: null,
        airQualityData: airQuality,
        sunData: null,
        extraMetrics: extraMetricsFromResponse,
        cityName: cityNameFromData,
        lat: lat,
        lon: lon,
      );

      if (!mounted || requestId != _requestGeneration) return false;
      setState(() {
        weatherData = weather;
        airQualityData = airQuality;
        extraMetrics = extraMetricsFromResponse;
        cityName = cityNameFromData;
        _isLoading = false;
        _hasData = true;
      });
      _loadingManager.finishLoading(fromStorage: false);
      return true;
    } catch (e, stackTrace) {
      debugPrint('ActivityScreen: загрузка не удалась - $e\n$stackTrace');
      if (!mounted || requestId != _requestGeneration || silentOnError) {
        return false;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _localeManager.getText('no_internet');
      });
      _loadingManager.setError(_errorMessage);
      return false;
    } finally {
      if (identical(_activeRequestClient, client)) {
        _activeRequestClient = null;
      }
      client?.close();
    }
  }

  /// Обрывает текущий сетевой запрос, если он ещё идёт.
  void _abortActiveRequest() {
    final client = _activeRequestClient;
    _activeRequestClient = null;
    client?.close();
  }

  Future<void> _fetchDataInBackground() async {
    await _loadWeather(silentOnError: true);
  }

  Future<void> _getLocationAndData() async {
    final requestId = ++_requestGeneration;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final position = await WeatherService.getCurrentPosition();
      if (!mounted || requestId != _requestGeneration) return;
      lat = position.latitude;
      lon = position.longitude;
      _hasSelectedLocation = false;
    } catch (e) {
      debugPrint('ActivityScreen: GPS недоступен, беру демо-координаты - $e');
      if (!mounted || requestId != _requestGeneration) return;
      lat = 55.7558;
      lon = 37.6173;
      _hasSelectedLocation = false;
    }
    await _loadWeather(showFullScreenLoader: true);
  }

  Future<void> _fetchData() => _loadWeather(showFullScreenLoader: true);

  Future<void> _refreshData() async {
    _loadingManager.startRefreshing();
    await _loadWeather();
  }

  Map<String, dynamic> _extractExtraMetrics(
    Map<String, dynamic> weather,
    Map<String, dynamic> normalizedMetrics,
  ) {
    final extra = weather['_extra'] as Map<String, dynamic>?;

    double? uvIndex;
    final uvValue = normalizedMetrics['uvIndex'] ?? extra?['uvIndex'];
    if (uvValue is num) {
      uvIndex = uvValue.toDouble();
    }

    int? precipProb;
    final precipValue =
        normalizedMetrics['precipitationProbability'] ??
        extra?['precipitationProbability'];
    if (precipValue is num) {
      precipProb = precipValue.toInt();
    }

    final dewPointValue = normalizedMetrics['dewPoint'] ?? extra?['dewPoint'];
    double? dewPoint = dewPointValue is num ? dewPointValue.toDouble() : null;

    if (dewPoint == null) {
      final temp = weather['main']?['temp'] ?? 0.0;
      final humidity = weather['main']?['humidity'] ?? 0.0;
      if (temp is num && humidity is num) {
        final t = temp.toDouble();
        final h = humidity.toDouble();
        if (t != 0 && h > 0) {
          const a = 17.27;
          const b = 237.7;
          final alpha = (a * t) / (b + t) + log(h / 100);
          dewPoint = (b * alpha) / (a - alpha);
        }
      }
    }

    final visibilityValue =
      normalizedMetrics['visibility'] ?? weather['visibility'];
    final double? visibility = visibilityValue is num
      ? visibilityValue.toDouble()
      : null;

    final radiationValue = normalizedMetrics['shortwaveRadiation'];

    return {
      'dewPoint': dewPoint,
      'visibility': visibility,
      'uvIndex': uvIndex,
      'precipitationProbability': precipProb,
        'shortwaveRadiation': radiationValue is num
          ? radiationValue.toDouble()
          : null,
    };
  }

  // 🔥 ИСПРАВЛЕНО: возвращаем null если нет данных
  double? _getAirQualityScore() {
    return WeatherUtils.calculateAirQualityScore(airQualityData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading && !_hasData)
              const AppLoadingOverlay()
            else if (_errorMessage.isNotEmpty && !_hasData)
              _buildError()
            else if (_hasData || weatherData != null)
              RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.white,
                backgroundColor: Colors.transparent,
                child: _buildContent(),
              )
            else
              Center(
                child: Text(
                  _localeManager.getText('no_data'),
                  style: const TextStyle(color: Color(0xFFa0a0a0)),
                ),
              ),
            if (_loadingManager.isOffline && _hasData)
              StatusToast(
                isVisible: true,
                title: _localeManager.getText('offline_mode'),
                backgroundColor: const Color(0xFFf59e0b),
              ),
            if (_loadingManager.hasError && _hasData && !_loadingManager.isOffline)
              StatusToast(
                isVisible: true,
                title: _loadingManager.errorMessage.isNotEmpty
                    ? _loadingManager.errorMessage
                    : _localeManager.getText('update_failed'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.grey[600], size: 64),
          const SizedBox(height: 16),
          Text(_errorMessage, style: const TextStyle(color: Color(0xFFa0a0a0))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _getLocationAndData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(_localeManager.getText('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ScrollConfiguration(
      behavior: NoGlowBehavior(),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (airQualityData != null) _buildAirQualitySection(),
            if (extraMetrics != null) ...[
              const SizedBox(height: 24),
              _buildExtraMetricsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFe3f2fd)],
            ).createShader(bounds),
            child: Text(
              _localeManager.getText('air_quality_title'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          if (_dataSystem.lastUpdateTime != null) ...[
            const SizedBox(height: 6),
            UpdateTimeIndicator(
              updateTime: _dataSystem.lastUpdateTime,
              isFromCache: _loadingManager.isUsingStorage,
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 НОВЫЙ МЕТОД: карточка "Нет данных"
  Widget _buildNoDataCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFa0a0a0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirQualitySection() {
    final airScore = _getAirQualityScore();
    
    // 🔥 ИСПРАВЛЕНО: если нет данных — показываем "Нет данных"
    if (airScore == null) {
      return _buildNoDataCard(
        icon: Icons.air,
        title: _localeManager.getText('air_quality_title'),
        message: _localeManager.getText('no_data'),
      );
    }

    final comp = airQualityData!['list'][0]['components'];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.air, color: Colors.white70, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _localeManager.getText('overall_index'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFa0a0a0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${airScore.toStringAsFixed(1)} / 10',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('pm25'),
                        comp['pm2_5']?.toStringAsFixed(1) ?? '--',
                        'µg/m³',
                        _localeManager.getText('pm25_desc')
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('pm10'),
                        comp['pm10']?.toStringAsFixed(0) ?? '--',
                        'µg/m³',
                        _localeManager.getText('pm10_desc')
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('co'),
                        comp['co']?.toStringAsFixed(0) ?? '--',
                        'µg/m³',
                        _localeManager.getText('co_desc')
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('no2'),
                        comp['no2']?.toStringAsFixed(0) ?? '--',
                        'µg/m³',
                        _localeManager.getText('no2_desc')
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('o3'),
                        comp['o3']?.toStringAsFixed(0) ?? '--',
                        'µg/m³',
                        _localeManager.getText('o3_desc')
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact(
                        _localeManager.getText('so2'),
                        comp['so2']?.toStringAsFixed(0) ?? '--',
                        'µg/m³',
                        _localeManager.getText('so2_desc')
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirMetricCompact(String label, String value, String unit, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFFa0a0a0), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Color(0xFFa0a0a0)),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraMetricsSection() {
    final uvIndex = extraMetrics?['uvIndex'];
    final dewPoint = extraMetrics?['dewPoint'];
    final visibility = extraMetrics?['visibility'];
    final precipProb = extraMetrics?['precipitationProbability'];
    final shortwaveRad = extraMetrics?['shortwaveRadiation'];

    if (uvIndex == null && dewPoint == null && visibility == null &&
        precipProb == null && shortwaveRad == null) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFe3f2fd)],
              ).createShader(bounds),
              child: Text(
                _localeManager.getText('additional_metrics'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (uvIndex != null)
            _buildMetricRow(
              icon: Icons.wb_sunny,
              label: _localeManager.getText('uv_index'),
              value: uvIndex.toStringAsFixed(1),
              description: _getUvDescription(uvIndex),
            ),
          if (uvIndex != null && dewPoint != null) const SizedBox(height: 10),
          if (dewPoint != null)
            _buildMetricRow(
              icon: Icons.water_drop,
              label: _localeManager.getText('dew_point'),
              value: '${dewPoint.round()}°C',
              description: _getDewPointDescription(dewPoint),
            ),
          if ((uvIndex != null || dewPoint != null) && visibility != null) const SizedBox(height: 10),
          if (visibility != null)
            _buildMetricRow(
              icon: Icons.visibility,
              label: _localeManager.getText('visibility'),
              value: '${(visibility / 1000).toStringAsFixed(1)} km',
              description: _getVisibilityDescription(visibility),
            ),
          if ((uvIndex != null || dewPoint != null || visibility != null) && precipProb != null)
            const SizedBox(height: 10),
          if (precipProb != null)
            _buildMetricRow(
              icon: Icons.umbrella,
              label: _localeManager.getText('precipitation_prob'),
              value: '$precipProb%',
              description: _getPrecipDescription(precipProb),
            ),
          if ((uvIndex != null || dewPoint != null || visibility != null || precipProb != null) &&
              shortwaveRad != null)
            const SizedBox(height: 10),
          if (shortwaveRad != null)
            _buildMetricRow(
              icon: Icons.solar_power,
              label: _localeManager.getText('solar_radiation'),
              value: '${shortwaveRad.round()} W/m²',
              description: _getRadiationDescription(shortwaveRad),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Icon(icon, color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFa0a0a0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFa0a0a0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUvDescription(dynamic uv) {
    if (uv == null) return _localeManager.getText('no_data');
    final uvVal = uv is double ? uv : double.tryParse(uv.toString()) ?? 0.0;
    if (uvVal <= 2) return _localeManager.getText('uv_low');
    if (uvVal <= 5) return _localeManager.getText('uv_moderate');
    if (uvVal <= 7) return _localeManager.getText('uv_high');
    if (uvVal <= 10) return _localeManager.getText('uv_very_high');
    return _localeManager.getText('uv_extreme');
  }

  String _getDewPointDescription(dynamic dewPoint) {
    if (dewPoint == null) return _localeManager.getText('no_data');
    final dp = dewPoint is double ? dewPoint : double.tryParse(dewPoint.toString()) ?? 0.0;
    if (dp > 20) return _localeManager.getText('dew_stuffy');
    if (dp > 15) return _localeManager.getText('dew_humid');
    if (dp > 10) return _localeManager.getText('dew_comfort');
    return _localeManager.getText('dew_dry');
  }

  String _getVisibilityDescription(dynamic visibility) {
    if (visibility == null) return _localeManager.getText('no_data');
    final vis = visibility is double ? visibility : double.tryParse(visibility.toString()) ?? 0.0;
    if (vis > 10000) return _localeManager.getText('visibility_excellent');
    if (vis > 5000) return _localeManager.getText('visibility_good');
    if (vis > 1000) return _localeManager.getText('visibility_moderate');
    return _localeManager.getText('visibility_fog');
  }

  String _getPrecipDescription(dynamic precipProb) {
    if (precipProb == null) return _localeManager.getText('no_data');
    final pp = precipProb is num ? precipProb.toInt() : int.tryParse(precipProb.toString()) ?? 0;
    if (pp == 0) return _localeManager.getText('precip_none');
    if (pp <= 20) return _localeManager.getText('precip_unlikely');
    if (pp <= 50) return _localeManager.getText('precip_possible');
    if (pp <= 80) return _localeManager.getText('precip_likely');
    return _localeManager.getText('precip_certain');
  }

  String _getRadiationDescription(dynamic radiation) {
    if (radiation == null) return _localeManager.getText('no_data');
    final rad = radiation is double ? radiation : double.tryParse(radiation.toString()) ?? 0.0;
    if (rad <= 0) return _localeManager.getText('radiation_night');
    if (rad <= 200) return _localeManager.getText('radiation_overcast');
    if (rad <= 500) return _localeManager.getText('radiation_cloudy');
    if (rad <= 800) return _localeManager.getText('radiation_partly');
    return _localeManager.getText('radiation_clear');
  }
}