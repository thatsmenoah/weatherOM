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
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Проверьте подключение к интернету';
      });
    }
  }

  String _getCityName() => weatherData?['name'] ?? 'Загрузка...';
  double _getAirQualityScore() => WeatherUtils.calculateAirQualityScore(airQualityData);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
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
                    'Качество воздуха',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Данные для ${_getCityName()}',
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
          
          if (airQualityData != null) _buildAirQualitySection(),
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
                      Icon(Icons.air, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Показатели качества',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(airScore).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getScoreColor(airScore).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${airScore.toStringAsFixed(1)}/10',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(airScore),
                          ),
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

  Color _getScoreColor(double score) {
    if (score >= 8) return const Color(0xFF10b981);
    if (score >= 6) return const Color(0xFF3b82f6);
    if (score >= 4) return const Color(0xFFf59e0b);
    return const Color(0xFFef4444);
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
}