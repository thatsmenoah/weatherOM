import 'package:flutter/material.dart';
import '../core/data_system.dart';
import '../core/tips_system.dart';
import '../core/loading_system.dart';
import '../services/weather_service.dart';
import '../utils/weather_utils.dart';
import '../screen/favorites_screen.dart';
import '../screen/header.dart';
import '../constants/weather_const.dart';
import '../widgets/move_sun.dart'; 
import '../utils/time_utils.dart';

// ==================== АНИМИРОВАННАЯ КАРТОЧКА СОВЕТА ====================

class AnimatedTipCard extends StatefulWidget {
  final String title;
  final String message;
  final String timeText;
  final Color accentColor;
  final IconData icon;
  final bool isImportant;

  const AnimatedTipCard({
    super.key,
    required this.title,
    required this.message,
    required this.timeText,
    required this.accentColor,
    required this.icon,
    this.isImportant = false,
  });

  @override
  State<AnimatedTipCard> createState() => _AnimatedTipCardState();
}

class _AnimatedTipCardState extends State<AnimatedTipCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.isImportant) {
      _pulseController = AnimationController(
        duration: WeatherConst.durPulse,
        vsync: this,
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.isImportant) {
      _pulseController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: WeatherConst.bgDetailCard,
        borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
        child: Padding(
          padding: WeatherConst.padTipCard,
          child: Row(
            children: [
              Container(
                width: WeatherConst.tipDotSize,
                height: WeatherConst.tipDotSize,
                decoration: BoxDecoration(
                  color: WeatherConst.bgForecastItem,
                  borderRadius: BorderRadius.circular(WeatherConst.radiusTipIcon),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.accentColor,
                    size: WeatherConst.tipIconSize,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: WeatherConst.tsTipTitle.copyWith(color: widget.accentColor),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.message, style: WeatherConst.tsTipMessage),
                  ],
                ),
              ),
              Container(
                padding: WeatherConst.padTimeBadge,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(WeatherConst.radiusTimeBadge),
                ),
                child: Text(
                  widget.timeText,
                  style: WeatherConst.tsTipTime.copyWith(
                    color: widget.accentColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isImportant && _pulseController != null) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulseController!, 
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
              border: Border.all(
                color: widget.accentColor.withValues(
                  alpha: 0.2 + _pulseController!.value * 0.2,
                ),
                width: 1,
              ),
            ),
            child: card,
          ),
        ),
      );
    }

    return FadeInWrapper(
      duration: WeatherConst.durFadeIn,
      offsetY: 10,
      child: card,
    );
  }
}

// ==================== ОСНОВНОЙ ЭКРАН ПОГОДЫ ====================

class WeatherScreen extends StatefulWidget {
  final GlobalKey? tipsKey;

  const WeatherScreen({super.key, this.tipsKey});

  @override
  State<WeatherScreen> createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? forecastData;
  Map<String, dynamic>? airQualityData;
  Map<String, dynamic>? sunData;
  Map<String, dynamic>? locationDetails;
  String cityName = 'Загрузка...';
  String displayLocation = 'Загрузка...';
  
  // ✅ НОВЫЕ ПОЛЯ ДЛЯ ОТОБРАЖЕНИЯ
  String locationText = 'Загрузка...';
  String? subLocationText;
  
  double? lat;
  double? lon;
  double? get currentLat => lat;
  double? get currentLon => lon;
  String get currentCityName => cityName;

  final GlobalKey _tipsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  final DataSystem _dataSystem = DataSystem();
  final TipsSystem _tipsSystem = TipsSystem();
  final LoadingStateManager _loadingManager = LoadingStateManager();

  bool _showStatusToast = false;
  bool _showCompactHeader = false;
  bool _isUsingFallback = false;
  
  Map<String, dynamic>? _cachedTip;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _loadingManager.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrollOffset = _scrollController.offset;
    if (scrollOffset > WeatherConst.scrollThreshold && !_showCompactHeader) {
      setState(() => _showCompactHeader = true);
    } else if (scrollOffset <= WeatherConst.scrollThreshold && _showCompactHeader) {
      setState(() => _showCompactHeader = false);
    }
  }

  void _updateTip() {
    if (weatherData != null) {
      _cachedTip = _tipsSystem.analyzeWeatherForTips(weatherData, forecastData);
    }
  }

  // ✅ НОВЫЙ МЕТОД: обновляет locationText и subLocationText
  void _updateLocationText() {
    if (locationDetails != null) {
      final geoResult = GeocodingResult.fromMap(locationDetails!);
      
      if (geoResult.district.isNotEmpty) {
        locationText = geoResult.district;        // РАЙОН
        if (geoResult.city.isNotEmpty && geoResult.city != geoResult.district) {
          subLocationText = geoResult.city;       // ГОРОД
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
    await _dataSystem.init();
    final priorityLocation = FavoritesStorage.getPriority();
    if (priorityLocation != null) {
      lat = priorityLocation.lat;
      lon = priorityLocation.lon;
      cityName = priorityLocation.name;
      displayLocation = priorityLocation.name;
    }
    _loadAllFromStorage();
    if (priorityLocation != null) {
      cityName = priorityLocation.name;
      displayLocation = priorityLocation.name;
    }
    if (weatherData == null) {
      _loadingManager.startLoading();
    }
    if (mounted) setState(() {});
    _updateWeatherInBackground();
  }

  Future<void> _updateWeatherInBackground() async {
    try {
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        if (!mounted) return;
        lat = position.latitude;
        lon = position.longitude;
      }
    } catch (e) {
      if (!mounted) return;
      final priorityLocation = FavoritesStorage.getPriority();
      if (priorityLocation != null) {
        lat = priorityLocation.lat;
        lon = priorityLocation.lon;
      } else {
        lat ??= 55.7558;
        lon ??= 37.6173;
      }
    }
    await _fetchFreshData();
  }

  Future<void> _saveToStorage() async {
    await _dataSystem.saveToCache(
      weatherData: weatherData,
      forecastData: forecastData,
      airQualityData: airQualityData,
      sunData: sunData,
      cityName: cityName,
      locationDetails: locationDetails,
    );
  }

  Future<void> _fetchFreshData() async {
    try {
      final response = await WeatherService.fetchAllWeatherDataWithFallback(
        lat!, 
        lon!,
      );
      
      if (!mounted) return;
      
      if (response.hasError) {
        if (weatherData != null) {
          setState(() => _showStatusToast = true);
          _loadingManager.setFallbackMode();
        } else {
          _loadingManager.setError('Не удалось загрузить погоду');
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
        _updateDisplayLocation(response);
        _updateLocationText(); // ← ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ
        cityName = response.weather['name'] ?? 'Текущее местоположение';
        _showStatusToast = false;
        _isUsingFallback = response.isFromOpenMeteo;
      });
      
      if (response.isFromOpenMeteo) {
        _loadingManager.setFallbackMode();
      } else {
        _loadingManager.finishLoading(fromStorage: false);
      }
      
      _updateTip();
      _saveToStorage();
      
    } catch (e) {
      if (!mounted) return;
      if (weatherData != null) {
        setState(() => _showStatusToast = true);
        if (e.toString().contains('SocketException') ||
            e.toString().contains('HandshakeException') ||
            e.toString().contains('HttpException')) {
          _loadingManager.setOfflineMode();
        } else {
          _loadingManager.setFallbackMode();
        }
      } else {
        if (e.toString().contains('SocketException') ||
            e.toString().contains('HandshakeException') ||
            e.toString().contains('HttpException')) {
          _loadingManager.setError('Проверьте подключение к интернету');
        } else {
          _loadingManager.setError('Ошибка сервера');
        }
        if (mounted) setState(() {});
      }
    }
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
    final allData = _dataSystem.getAllCachedData();
    if (allData != null) {
      weatherData = allData['weather'];
      forecastData = allData['forecast'];
      airQualityData = allData['airQuality'];
      sunData = allData['sunData'];
      cityName = allData['city'] ?? 'Загрузка...';
      locationDetails = allData['locationDetails'] as Map<String, dynamic>?;
      
      if (locationDetails != null) {
        final geoResult = GeocodingResult.fromMap(locationDetails!);
        displayLocation = geoResult.displayName.isNotEmpty 
            ? geoResult.displayName 
            : cityName;
        _updateLocationText(); // ← ОБНОВЛЯЕМ ОТОБРАЖЕНИЕ
      } else {
        displayLocation = cityName;
        locationText = cityName;
        subLocationText = null;
      }
      
      _updateTip();
      final timestamp = allData['timestamp'];
      if (timestamp != null && mounted) {
        try {
          final updateTime = DateTime.parse(timestamp.toString());
          _loadingManager.setLastUpdateTime(updateTime);
        } catch (_) {}
      }
      if (mounted) setState(() {});
    }
  }

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: WeatherConst.durScrollAnim,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> setLocation(double newLat, double newLon, String newCityName) async {
    setState(() {
      lat = newLat;
      lon = newLon;
      cityName = newCityName;
      displayLocation = newCityName;
      locationText = newCityName;
      subLocationText = null;
      _showStatusToast = false;
    });
    _loadingManager.startLoading();
    if (mounted) setState(() {});
    await _fetchFreshData();
  }

  Future<void> _refreshWeather() async {
    _loadingManager.startRefreshing();
    if (mounted) setState(() {});
    try {
      final position = await WeatherService.getCurrentPosition();
      if (!mounted) return;
      lat = position.latitude;
      lon = position.longitude;
    } catch (e) {
      if (!mounted) return;
      final priorityLocation = FavoritesStorage.getPriority();
      if (priorityLocation != null) {
        lat = priorityLocation.lat;
        lon = priorityLocation.lon;
      } else {
        lat ??= 55.7558;
        lon ??= 37.6173;
      }
    }
    await _fetchFreshData();
    _updateTip(); 
    if (mounted) setState(() {});
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
                child: RepaintBoundary(
                  child: AnimatedOpacity(
                    opacity: _showCompactHeader ? 1.0 : 0.0,
                    duration: WeatherConst.durHeaderAnim,
                    curve: Curves.easeInOut,
                    child: AnimatedSlide(
                      offset: _showCompactHeader ? Offset.zero : const Offset(0, -0.15),
                      duration: WeatherConst.durHeaderAnim,
                      curve: Curves.easeInOut,
                      child: CompactWeatherHeader(
                        cityName: locationText,          // ← РАЙОН
                        temp: weatherData!['main']['temp'].round(),
                        feelsLike: weatherData!['main']['feels_like'].round(),
                        iconCode: weatherData!['weather'][0]['icon'],
                        description: weatherData!['weather'][0]['description'],
                        now: DateTime.now(),
                        isUsingFallback: _isUsingFallback,
                      ),
                    ),
                  ),
                ),
              ),
            if (_showStatusToast)
              RepaintBoundary(
                child: Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: StatusToast(
                      isVisible: _showStatusToast,
                      title: _loadingManager.isOffline ? 'Нет сети' : 'Перебои АПИ',
                      onDismiss: () => setState(() => _showStatusToast = false),
                    ),
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
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (weatherData != null) {
      return RefreshIndicator(
        onRefresh: _refreshWeather,
        color: WeatherConst.textPrimary,
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
                  Container(key: widget.tipsKey ?? _tipsKey, child: _buildTipCard()),
                  const SizedBox(height: 12),
                  _buildGlassCard(_buildHourlyForecast()),
                  const SizedBox(height: 12),
                  _buildGlassCard(_buildDailyForecast()),
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

  // ==================== КАРТОЧКА СОВЕТА ====================
  
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

  // ==================== ОСНОВНАЯ КАРТОЧКА ПОГОДЫ ====================
  
  Widget _buildMainWeatherCard() {
    if (weatherData == null) return const SizedBox.shrink();

    DateTime now = DateTime.now();
    double humidity = weatherData!['main']['humidity'].toDouble();
    double windSpeed = weatherData!['wind']['speed'].toDouble();
    int temp = weatherData!['main']['temp'].round();
    int feelsLike = weatherData!['main']['feels_like'].round();
    String description = weatherData!['weather'][0]['description'];
    String iconCode = weatherData!['weather'][0]['icon'];
    String capitalizedDescription = WeatherUtils.capitalize(description);

    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius: BorderRadius.circular(WeatherConst.radiusCard),
          border: Border.all(color: WeatherConst.textPrimary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WeatherConst.radiusCard),
          child: Padding(
            padding: WeatherConst.padCardContent,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationText, // ← РАЙОН
                                      style: WeatherConst.tsCityName, 
                                      maxLines: 2, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subLocationText != null && subLocationText!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          subLocationText!, // ← ГОРОД
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(WeatherUtils.formatDate(now), style: WeatherConst.tsDateLabel),
                          const SizedBox(height: 6),
                          UpdateTimeIndicator(
                            updateTime: _loadingManager.lastUpdateTime,
                            isFromCache: _loadingManager.isUsingStorage,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WeatherConst.bgCardLighter,
                        borderRadius: BorderRadius.circular(WeatherConst.radiusWeatherIconBg),
                      ),
                      child: Icon(
                        WeatherUtils.getWeatherIcon(iconCode),
                        color: WeatherConst.textPrimary,
                        size: WeatherConst.mainWeatherIconSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(child: Text('$temp°', style: WeatherConst.tsHeroTemp)),
                const SizedBox(height: 8),
                Center(child: Text(capitalizedDescription, style: WeatherConst.tsDescription)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatHumidity(humidity),
                        label: 'Влажность',
                        color: WeatherConst.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatWindSpeed(windSpeed),
                        label: 'Ветер: ${WeatherUtils.getWindDirection(weatherData!['wind']['deg'])}',
                        color: WeatherConst.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatPressure(weatherData!['main']['pressure'].toDouble()),
                        label: 'Давление',
                        color: WeatherConst.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatTemp(feelsLike),
                        label: 'Ощущается',
                        color: WeatherConst.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({required String value, required String label, required Color color}) {
    return Container(
      padding: WeatherConst.padDetailCard,
      decoration: BoxDecoration(
        color: WeatherConst.bgDetailCard,
        borderRadius: BorderRadius.circular(WeatherConst.radiusDetailCard),
        border: Border.all(color: WeatherConst.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(value, style: WeatherConst.tsDetailValue.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: WeatherConst.tsDetailLabel),
        ],
      ),
    );
  }

  // ==================== УНИВЕРСАЛЬНАЯ КАРТОЧКА БЕЗ ЗАГОЛОВКА ====================
  
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

  // ==================== ПОЧАСОВОЙ ПРОГНОЗ ====================
  
  Widget _buildHourlyForecast() {
    if (forecastData == null) return const SizedBox.shrink();
    List<dynamic> list = forecastData!['list'];
    List<Widget> hourlyWidgets = [];
    
    for (int i = 0; i < 8 && i < list.length; i++) {
      var item = list[i];
      DateTime time = DateTime.parse(item['dt_txt']);
      bool isNow = i == 0;
      
      String hour;
      if (isNow) {
        hour = 'Сейчас';
      } else {
        hour = TimeUtils.formatTimeShort(context, time);
      }
      
      double temp = item['main']['temp'];
      String iconCode = item['weather'][0]['icon'];
      String shortDesc = WeatherUtils.getShortWeatherDescription(iconCode);
      double? pop = item['pop'] as double?;
      int? popPercent;
      if (pop != null) {
        popPercent = (pop * 100).round();
      }
      
      hourlyWidgets.add(FadeInWrapper(
        duration: Duration(milliseconds: 300 + (i * 50)),
        offsetY: 20,
        child: _forecastItem(
          hour, 
          shortDesc, 
          iconCode, 
          WeatherUtils.formatTemp(temp),
          pop: popPercent,
        ),
      ));
    }
    return Column(children: hourlyWidgets);
  }

  // ==================== 5-ДНЕВНЫЙ ПРОГНОЗ ====================
  
  Widget _buildDailyForecast() {
    if (forecastData == null) return const SizedBox.shrink();
    
    Map<String, List<Map<String, dynamic>>> groupedByDay = {};
    List<dynamic> list = forecastData!['list'];
    
    for (var item in list) {
      String date = item['dt_txt'].split(' ')[0];
      groupedByDay.putIfAbsent(date, () => []).add(item);
    }
    
    List<Widget> dailyWidgets = [];
    int index = 0;
    groupedByDay.forEach((date, items) {
      if (index >= 5) return;
      
      double totalTemp = 0;
      double maxPop = 0;
      String iconCode = '';
      
      for (var item in items) {
        totalTemp += item['main']['temp'];
        if (item['pop'] != null) {
          double pop = (item['pop'] as double) * 100;
          if (pop > maxPop) maxPop = pop;
        }
        if (iconCode.isEmpty) {
          iconCode = item['weather'][0]['icon'];
        }
      }
      
      double avgTemp = totalTemp / items.length;
      int popPercent = maxPop.round();
      
      DateTime dateTime = DateTime.parse(date);
      String weekday = WeatherUtils.getWeekday(dateTime);
      String label = WeatherUtils.getDailyForecastLabel(index);
      if (label.isNotEmpty) {
        weekday = label;
      }
      
      String shortDesc = WeatherUtils.getShortWeatherDescription(iconCode);
      
      dailyWidgets.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (index * 50)),
          offsetY: 20,
          child: _forecastItem(
            weekday, 
            shortDesc, 
            iconCode, 
            WeatherUtils.formatTemp(avgTemp),
            isDaily: true, 
            pop: popPercent,
          ),
        ),
      );
      index++;
    });
    
    return Column(children: dailyWidgets);
  }

  // ==================== ЭЛЕМЕНТ ПРОГНОЗА ====================
  
  Widget _forecastItem(
    String time, 
    String desc, 
    String iconCode, 
    String temp, {
    bool isDaily = false,
    int? pop,
  }) {
    IconData rainIcon = Icons.water_drop_outlined;
    Color rainColor = Colors.grey.withValues(alpha: 0.5);
    
    if (pop != null && pop > 0) {
      rainIcon = Icons.water_drop_outlined;
      rainColor = Colors.grey.withValues(alpha: 0.5);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: WeatherConst.padForecastItem,
      decoration: BoxDecoration(
        color: WeatherConst.bgForecastItem,
        borderRadius: BorderRadius.circular(WeatherConst.radiusForecastItem),
        border: Border.all(color: WeatherConst.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDaily ? 115 : 55,
            child: Text(
              time, 
              style: WeatherConst.tsForecastTime.copyWith(fontSize: isDaily ? 12 : 13), 
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text(desc, style: WeatherConst.tsForecastDesc)),
          if (pop != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rainIcon,
                    size: 14,
                    color: rainColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$pop%',
                    style: TextStyle(
                      fontSize: 12,
                      color: rainColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          Icon(
            WeatherUtils.getWeatherIcon(iconCode), 
            color: WeatherConst.textPrimary, 
            size: WeatherConst.forecastIconSize,
          ),
          const SizedBox(width: 12),
          Text(temp, style: WeatherConst.tsForecastTemp),
        ],
      ),
    );
  }

  // ==================== КАРТОЧКА СОЛНЦА ====================

  Widget _buildSunContent() {
    if (sunData == null) return const SizedBox.shrink();

    final sunrise = sunData!['sunrise'] as DateTime?;
    final sunset = sunData!['sunset'] as DateTime?;

    if (sunrise == null || sunset == null) return const SizedBox.shrink();

    final sunriseStr = TimeUtils.formatTime(context, sunrise);
    final sunsetStr = TimeUtils.formatTime(context, sunset);

    return Column(
      children: [
        MoveSun(
          sunrise: sunrise,
          sunset: sunset,
          height: 100,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Рассвет',
                  style: WeatherConst.tsSunLabel.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sunriseStr,
                  style: WeatherConst.tsSunTime.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Закат',
                  style: WeatherConst.tsSunLabel.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sunsetStr,
                  style: WeatherConst.tsSunTime.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ==================== КАЧЕСТВО ВОЗДУХА ====================
  
  Widget _buildAirQualityContent() {
    if (airQualityData == null) return const SizedBox.shrink();
    int aqi = 2;
    String aqiText = 'Нет данных';
    if (airQualityData!['list'] != null && airQualityData!['list'].isNotEmpty) {
      aqi = airQualityData!['list'][0]['main']['aqi'];
      aqiText = WeatherUtils.getAirQualityText(aqi);
    }
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(children: [
                Text(aqiText, style: WeatherConst.tsAirQualityValue.copyWith(color: WeatherConst.textPrimary)),
                const SizedBox(height: 4),
                const Text('Качество воздуха', style: WeatherConst.tsAirQualityLabel),
              ]),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          child: Text(
            'AQI',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: WeatherConst.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== FADE IN WRAPPER ====================

class FadeInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;

  const FadeInWrapper({
    super.key,
    required this.child,
    this.duration = WeatherConst.durFadeIn,
    this.offsetY = 20.0,
  });

  @override
  State<FadeInWrapper> createState() => _FadeInWrapperState();
}

class _FadeInWrapperState extends State<FadeInWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, widget.offsetY / 100), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}