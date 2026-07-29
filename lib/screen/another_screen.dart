import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/weather_service.dart';
import '../utils/weather_utils.dart';
import '../core/data_system.dart';
import '../core/loading_system.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // ДАННЫЕ
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airQualityData;
  Map<String, dynamic>? extraMetrics;
  String? cityName;
  double? lat;
  double? lon;
  
  // СОСТОЯНИЕ
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _errorMessage = '';
  bool _hasData = false;
  
  // КЕШ И ЗАГРУЗКА
  final DataSystem _dataSystem = DataSystem(fileName: 'activity_data.json');
  final LoadingStateManager _loadingManager = LoadingStateManager();
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initDataSystem();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loadingManager.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasData) {
      _fetchDataInBackground();
    }
  }

  Future<void> _initDataSystem() async {
    await _dataSystem.init();
    
    final cachedData = _dataSystem.getAllCachedData();
    
    if (cachedData != null && _dataSystem.isDataValid) {
      _applyDataFromCache(cachedData);
      _loadingManager.finishLoading(fromStorage: true);
      setState(() {
        _hasData = true;
        _isLoading = false;
      });
      
      _fetchDataInBackground();
    } else if (cachedData != null && !_dataSystem.isDataValid) {
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
      
      if (cachedData.containsKey('lat')) {
        lat = cachedData['lat'] as double?;
        lon = cachedData['lon'] as double?;
      }
    });
  }

  Future<void> _fetchDataInBackground() async {
    try {
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        lat = position.latitude;
        lon = position.longitude;
      }
      
      final data = await WeatherService.fetchWeatherAndAirQuality(lat!, lon!);
      final metrics = await WeatherService.fetchExtraMetricsFromOpenMeteo(lat!, lon!);
      
      final cityNameFromData = data['weather']?['name'] ?? 'Неизвестно';
      
      await _dataSystem.saveToCache(
        weatherData: data['weather'],
        forecastData: null,
        airQualityData: data['airQuality'],
        sunData: null,
        extraMetrics: metrics,
        cityName: cityNameFromData,
        lat: lat,
        lon: lon,
      );
      
      if (mounted) {
        setState(() {
          weatherData = data['weather'];
          airQualityData = data['airQuality'];
          extraMetrics = metrics;
          cityName = cityNameFromData;
          _hasData = true;
        });
        _loadingManager.finishLoading(fromStorage: false);
      }
    } catch (e) {
      // ФОНОВАЯ ОШИБКА - ИГНОРИРУЕМ, Т.К. ДАННЫЕ УЖЕ ПОКАЗАНЫ
    }
  }

  Future<void> _getLocationAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final position = await WeatherService.getCurrentPosition();
      lat = position.latitude;
      lon = position.longitude;
      await _fetchData();
    } catch (e) {
      lat = 55.7558;
      lon = 37.6173;
      await _fetchData();
    }
  }

  Future<void> _fetchData() async {
    try {
      final data = await WeatherService.fetchWeatherAndAirQuality(lat!, lon!);
      final metrics = await WeatherService.fetchExtraMetricsFromOpenMeteo(lat!, lon!);
      
      final cityNameFromData = data['weather']?['name'] ?? 'Неизвестно';
      
      await _dataSystem.saveToCache(
        weatherData: data['weather'],
        forecastData: null,
        airQualityData: data['airQuality'],
        sunData: null,
        extraMetrics: metrics,
        cityName: cityNameFromData,
        lat: lat,
        lon: lon,
      );
      
      setState(() {
        weatherData = data['weather'];
        airQualityData = data['airQuality'];
        extraMetrics = metrics;
        cityName = cityNameFromData;
        _isLoading = false;
        _hasData = true;
      });
      
      _loadingManager.finishLoading(fromStorage: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Проверьте подключение к интернету';
      });
      _loadingManager.setError(_errorMessage);
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    _loadingManager.startRefreshing();
    
    try {
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        lat = position.latitude;
        lon = position.longitude;
      }
      
      final data = await WeatherService.fetchWeatherAndAirQuality(lat!, lon!);
      final metrics = await WeatherService.fetchExtraMetricsFromOpenMeteo(lat!, lon!);
      
      final cityNameFromData = data['weather']?['name'] ?? 'Неизвестно';
      
      await _dataSystem.saveToCache(
        weatherData: data['weather'],
        forecastData: null,
        airQualityData: data['airQuality'],
        sunData: null,
        extraMetrics: metrics,
        cityName: cityNameFromData,
        lat: lat,
        lon: lon,
      );
      
      setState(() {
        weatherData = data['weather'];
        airQualityData = data['airQuality'];
        extraMetrics = metrics;
        cityName = cityNameFromData;
        _isRefreshing = false;
        _hasData = true;
      });
      
      _loadingManager.finishLoading(fromStorage: false);
    } catch (e) {
      setState(() {
        _isRefreshing = false;
      });
      _loadingManager.setError('Ошибка обновления');
    }
  }

  double _getAirQualityScore() => WeatherUtils.calculateAirQualityScore(airQualityData);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading && !_hasData)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              )
            else if (_errorMessage.isNotEmpty && !_hasData)
              _buildError()
            else if (_hasData || weatherData != null)
              RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.white,
                child: _buildContent(),
              )
            else
              const Center(
                child: Text(
                  'Нет данных',
                  style: TextStyle(color: Color(0xFFa0a0a0)),
                ),
              ),
            
            if (_isRefreshing) _buildRefreshOverlay(),
            
            if (_loadingManager.isOffline && _hasData)
              const StatusToast(
                isVisible: true,
                title: 'Оффлайн режим • Используются кешированные данные',
                backgroundColor: Color(0xFFf59e0b),
              ),
            
            if (_loadingManager.hasError && _hasData && !_loadingManager.isOffline)
              StatusToast(
                isVisible: true,
                title: _loadingManager.errorMessage.isNotEmpty 
                    ? _loadingManager.errorMessage 
                    : 'Не удалось обновить данные',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
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
            child: const Text('Повторить'),
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
          child: const Text(
            'Качество воздуха',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        // ❌ СТРОКА "Данные для ..." УДАЛЕНА
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

  Widget _buildAirQualitySection() {
    final airScore = _getAirQualityScore();
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
                            const Text(
                              'Общий индекс',
                              style: TextStyle(
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
                      Expanded(child: _buildAirMetricCompact('PM2.5', comp['pm2_5']?.toStringAsFixed(1) ?? '--', 'µg/m³', 'Мелкие частицы')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('PM10', comp['pm10']?.toStringAsFixed(0) ?? '--', 'µg/m³', 'Крупные частицы')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact('CO', comp['co'] != null ? (comp['co'] / 1000).toStringAsFixed(1) : '--', 'ppm', 'Угарный газ')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('NO₂', comp['no2']?.toStringAsFixed(0) ?? '--', 'ppb', 'Диоксид азота')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact('O₃', comp['o3']?.toStringAsFixed(0) ?? '--', 'ppb', 'Озон')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('SO₂', comp['so2']?.toStringAsFixed(0) ?? '--', 'ppb', 'Диоксид серы')),
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
          if (uvIndex != null) ...[
            Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFe3f2fd)],
                ).createShader(bounds),
                child: const Text(
                  'Дополнительно',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.wb_sunny,
              label: 'УФ-индекс',
              value: uvIndex.toStringAsFixed(1),
              description: _getUvDescription(uvIndex),
            ),
          ],
          
          if (uvIndex != null && dewPoint != null) const SizedBox(height: 10),
          
          if (dewPoint != null)
            _buildMetricRow(
              icon: Icons.water_drop,
              label: 'Точка росы',
              value: '${dewPoint.round()}°C',
              description: _getDewPointDescription(dewPoint),
            ),
          
          if ((uvIndex != null || dewPoint != null) && visibility != null) const SizedBox(height: 10),
          
          if (visibility != null)
            _buildMetricRow(
              icon: Icons.visibility,
              label: 'Видимость',
              value: '${(visibility / 1000).toStringAsFixed(1)} км',
              description: _getVisibilityDescription(visibility),
            ),
          
          if ((uvIndex != null || dewPoint != null || visibility != null) && precipProb != null) 
            const SizedBox(height: 10),
          
          if (precipProb != null)
            _buildMetricRow(
              icon: Icons.umbrella,
              label: 'Вероятность осадков',
              value: '$precipProb%',
              description: _getPrecipDescription(precipProb),
            ),
          
          if ((uvIndex != null || dewPoint != null || visibility != null || precipProb != null) && 
              shortwaveRad != null) 
            const SizedBox(height: 10),
          
          if (shortwaveRad != null)
            _buildMetricRow(
              icon: Icons.solar_power,
              label: 'Солнечная радиация',
              value: '${shortwaveRad.round()} Вт/м²',
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
    if (uv == null) return 'Нет данных';
    final uvVal = uv is double ? uv : double.tryParse(uv.toString()) ?? 0.0;
    if (uvVal <= 2) return 'Низкий';
    if (uvVal <= 5) return 'Умеренный';
    if (uvVal <= 7) return 'Высокий';
    if (uvVal <= 10) return 'Очень высокий';
    return 'Экстремальный';
  }
  
  String _getDewPointDescription(dynamic dewPoint) {
    if (dewPoint == null) return 'Нет данных';
    final dp = dewPoint is double ? dewPoint : double.tryParse(dewPoint.toString()) ?? 0.0;
    if (dp > 20) return 'Душно';
    if (dp > 15) return 'Влажно';
    if (dp > 10) return 'Комфортно';
    return 'Сухо';
  }
  
  String _getVisibilityDescription(dynamic visibility) {
    if (visibility == null) return 'Нет данных';
    final vis = visibility is double ? visibility : double.tryParse(visibility.toString()) ?? 0.0;
    if (vis > 10000) return 'Отличная';
    if (vis > 5000) return 'Хорошая';
    if (vis > 1000) return 'Средняя';
    return 'Туман';
  }
  
  String _getPrecipDescription(dynamic precipProb) {
    if (precipProb == null) return 'Нет данных';
    final pp = precipProb is num ? precipProb.toInt() : int.tryParse(precipProb.toString()) ?? 0;
    if (pp == 0) return 'Без осадков';
    if (pp <= 20) return 'Маловероятно';
    if (pp <= 50) return 'Возможно';
    if (pp <= 80) return 'Вероятно';
    return 'Точно будет';
  }
  
  String _getRadiationDescription(dynamic radiation) {
    if (radiation == null) return 'Нет данных';
    final rad = radiation is double ? radiation : double.tryParse(radiation.toString()) ?? 0.0;
    if (rad <= 0) return 'Ночь';
    if (rad <= 200) return 'Пасмурно';
    if (rad <= 500) return 'Облачно';
    if (rad <= 800) return 'Переменная облачность';
    return 'Ясно';
  }
}