import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/weather_service.dart';
import '../utils/weather_utils.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? airQualityData;
  bool isLoading = true;
  bool isRefreshing = false;
  String errorMessage = '';
  double? lat;
  double? lon;
  final ScrollController _scrollController = ScrollController();

  Map<String, double> activityScores = {
    'running': 0,
    'cycling': 0,
    'walking': 0,
    'photography': 0,
  };

  @override
  void initState() {
    super.initState();
    _getLocationAndData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });
    await _fetchData();
    setState(() {
      isRefreshing = false;
    });
  }

  Future<void> _getLocationAndData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final position = await WeatherService.getCurrentPosition();
      lat = position.latitude;
      lon = position.longitude;
      await _fetchData();
    } catch (e) {
      // Используем Москву по умолчанию
      lat = 55.7558;
      lon = 37.6173;
      await _fetchData();
    }
  }

  Future<void> _fetchData() async {
    try {
      final data = await WeatherService.fetchWeatherAndAirQuality(lat!, lon!);
      
      setState(() {
        weatherData = data['weather'];
        airQualityData = data['airQuality'];
        _calculateAllScores();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Проверьте подключение к интернету';
      });
    }
  }

  void _calculateAllScores() {
    if (weatherData == null) return;
    
    final activities = ['running', 'cycling', 'walking', 'photography'];
    for (final activity in activities) {
      activityScores[activity] = WeatherUtils.calculateActivityScore(
        activity,
        weatherData,
        airQualityData,
      );
    }
  }

  String _getCityName() => weatherData?['name'] ?? 'Загрузка...';
  double _getAirQualityScore() => WeatherUtils.calculateAirQualityScore(airQualityData);

 @override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF080808), // Очень темный, почти черный
    ),
    child: SafeArea(
      child: Stack(
        children: [
          if (isLoading && weatherData == null)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            )
          else if (errorMessage.isNotEmpty && weatherData == null)
            _buildError()
          else
            RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.white,
              child: _buildContent(),
            ),
          
          if (isRefreshing) _buildRefreshOverlay(),
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
          Text(errorMessage, style: const TextStyle(color: Color(0xFFa0a0a0))),
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
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
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
                    'Активности',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Условия для занятий в ${_getCityName()}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFa0a0a0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActivityCard('Бег', 'running', const Color(0xFF10b981), Icons.directions_run),
              _buildActivityCard('Велосипед', 'cycling', const Color(0xFF3b82f6), Icons.directions_bike),
              _buildActivityCard('Прогулка', 'walking', const Color(0xFF8b5cf6), Icons.directions_walk),
              _buildActivityCard('Фото', 'photography', const Color(0xFFf59e0b), Icons.camera_alt),
            ],
          ),
          
          const SizedBox(height: 20),
          
          if (airQualityData != null) _buildAirQualitySection(),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, String key, Color accentColor, IconData icon) {
    final score = activityScores[key] ?? 0;
    String scoreText = '${score.toStringAsFixed(1)}/10';
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.9 + (0.1 * opacity),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: accentColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                    ).createShader(bounds),
                    child: Text(
                      scoreText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirQualitySection() {
    final airScore = _getAirQualityScore();
    final aqiText = WeatherUtils.getAirQualityTextByScore(airScore);
    final aqiColor = WeatherUtils.getAirQualityColorByScore(airScore);
    
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
                      Icon(Icons.air, color: aqiColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Качество воздуха',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${airScore.toStringAsFixed(1)}/10',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: aqiColor,
                            shadows: [Shadow(blurRadius: 6, color: aqiColor.withValues(alpha: 0.4))],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: aqiColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: aqiColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            aqiText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: aqiColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact('PM2.5', comp['pm2_5']?.toStringAsFixed(1) ?? '--', 'µg/m³', 'Мелкие частицы', 'Отлично')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('PM10', comp['pm10']?.toStringAsFixed(0) ?? '--', 'µg/m³', 'Крупные частицы', 'Хорошо')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact('CO', comp['co'] != null ? (comp['co'] / 1000).toStringAsFixed(1) : '--', 'ppm', 'Угарный газ', 'Норма')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('NO₂', comp['no2']?.toStringAsFixed(0) ?? '--', 'ppb', 'Диоксид азота', 'Норма')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildAirMetricCompact('O₃', comp['o3']?.toStringAsFixed(0) ?? '--', 'ppb', 'Озон', 'Хорошо')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildAirMetricCompact('SO₂', comp['so2']?.toStringAsFixed(0) ?? '--', 'ppb', 'Диоксид серы', 'Норма')),
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

  Widget _buildAirMetricCompact(String label, String value, String unit, String description, String status) {
    Color statusColor;
    if (status == 'Отлично') {
      statusColor = const Color(0xFF10b981);
    } else if (status == 'Хорошо') {
      statusColor = const Color(0xFF3b82f6);
    } else {
      statusColor = const Color(0xFFf59e0b);
    }
    
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
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}