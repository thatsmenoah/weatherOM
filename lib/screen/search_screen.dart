import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/weather_service.dart';
import '../core/locale_manager.dart';
import '../core/loading_system.dart';
import '../utils/weather_utils.dart';

class SearchScreen extends StatefulWidget {
  final Function(double lat, double lon, String name)? onLocationSelected;

  const SearchScreen({super.key, this.onLocationSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final LocaleManager _localeManager = LocaleManager();

  late MapController _mapController;
  LatLng _center = const LatLng(55.7558, 37.6173);
  bool _isMapReady = false;

  LatLng? _selectedPosition;
  Map<String, dynamic>? _selectedWeather;
  String? _selectedLocationName;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _getUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await WeatherService.getCurrentPosition();
      if (mounted) {
        final point = LatLng(position.latitude, position.longitude);
        setState(() {
          _center = point;
          _selectedPosition = point;
          _isMapReady = true;
          _isLoading = true;
        });
        _mapController.move(_center, 14);
        _fetchLocationData(point);
      }
    } catch (e) {
      if (mounted) {
        final point = const LatLng(55.7558, 37.6173);
        setState(() {
          _center = point;
          _selectedPosition = point;
          _isMapReady = true;
          _isLoading = true;
        });
        _mapController.move(_center, 10);
        _fetchLocationData(point);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPosition = point;
      _isLoading = true;
      _selectedWeather = null;
    });
    _mapController.move(point, 14);
    _fetchLocationData(point);
  }

  Future<void> _fetchLocationData(LatLng point) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _selectedWeather = null;
    });

    try {
      final localeManager = LocaleManager();
      final locationDetails = await WeatherService.getLocationDetails(
        point.latitude,
        point.longitude,
        localeManager,
      );

      final response = await WeatherService.fetchAllWeatherData(
        point.latitude,
        point.longitude,
      );

      if (response.hasError) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _localeManager.getText('no_internet');
        });
        return;
      }

      if (mounted) {
        setState(() {
          _selectedLocationName = locationDetails.displayName;
          _selectedWeather = response.weather;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _localeManager.getText('error');
        });
      }
    }
  }

  void _selectLocation() {
    if (_selectedPosition == null || _selectedWeather == null) return;

    final name = _selectedLocationName ?? _localeManager.getText('unknown');

    widget.onLocationSelected?.call(
      _selectedPosition!.latitude,
      _selectedPosition!.longitude,
      name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // КАРТА — НА ВЕСЬ ЭКРАН. БЕЗ РАМОК.
            _isMapReady
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 18,
                      onTap: _onMapTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.weather_app',
                      ),
                      if (_selectedPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedPosition!,
                              width: 44,
                              height: 44,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.grey,
                                size: 44,
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),

            // КАРТОЧКА С ДАННЫМИ (ПОЯВЛЯЕТСЯ ПОСЛЕ ЗАГРУЗКИ)
            if (_selectedWeather != null)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _buildLocationCard(),
                ),
              ),

            // ИНДИКАТОР ЗАГРУЗКИ "One second..."
            if (_isLoading)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'One second...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),

            // ОШИБКА
            if (_hasError)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: StatusToast(
                  isVisible: true,
                  title: _errorMessage,
                  onDismiss: () => setState(() => _hasError = false),
                ),
              ),

            // ПОЛОСКА ДЛЯ СВАЙПА
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final temp = _selectedWeather!['main']['temp'].round();
    final feelsLike = _selectedWeather!['main']['feels_like'].round();
    final iconCode = _selectedWeather!['weather'][0]['icon'];
    final description = WeatherUtils.getShortWeatherDescription(
      iconCode,
      _localeManager,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        WeatherUtils.getWeatherIcon(iconCode),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLocationName ??
                                _localeManager.getText('unknown'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$temp°',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_localeManager.getText('feels_like')} $feelsLike°',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // КНОПКА ADD — ТОЛЬКО ТЕКСТ
                GestureDetector(
                  onTap: _selectLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}