import 'package:flutter/material.dart';
import '../core/data_system.dart';
import '../core/tips_system.dart';
import '../core/loading_system.dart';
import '../services/weather_service.dart';
import '../utils/weather_utils.dart';
import '../screen/favorites_screen.dart';
import '../screen/header.dart';
import '../constants/weather_const.dart';

// ========== АНИМИРОВАННАЯ КАРТОЧКА СОВЕТА ==========

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
  late AnimationController _pulseController;

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
      _pulseController.dispose();
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
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: widget.accentColor.withValues(alpha: 0.4),
              ),
            ),
            // BackdropFilter убран — заменён на полупрозрачный фон
            Padding(
              padding: WeatherConst.padTipCard,
              child: Row(
                children: [
                  Container(
                    width: WeatherConst.tipDotSize,
                    height: WeatherConst.tipDotSize,
                    decoration: BoxDecoration(
                      color: WeatherConst.bgForecastItem,
                      borderRadius:
                          BorderRadius.circular(WeatherConst.radiusTipIcon),
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
                          style: WeatherConst.tsTipTitle
                              .copyWith(color: widget.accentColor),
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
                      borderRadius: BorderRadius.circular(
                          WeatherConst.radiusTimeBadge),
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
          ],
        ),
      ),
    );

    if (widget.isImportant) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(WeatherConst.radiusTipCard),
              border: Border.all(
                color: widget.accentColor.withValues(
                  alpha: 0.2 + _pulseController.value * 0.2,
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

// ========== ОСНОВНОЙ ЭКРАН ПОГОДЫ ==========

class WeatherScreen extends StatefulWidget {
  final GlobalKey? tipsKey;

  const WeatherScreen({super.key, this.tipsKey});

  @override
  State<WeatherScreen> createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? forecastData;
  Map<String, dynamic>? airQualityData;
  String cityName = 'Загрузка...';
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _scrollController.addListener(_onScroll);
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
    } else if (scrollOffset <= WeatherConst.scrollThreshold &&
        _showCompactHeader) {
      setState(() => _showCompactHeader = false);
    }
  }

  Future<void> _initializeApp() async {
    await _dataSystem.init();

    final priorityLocation = FavoritesStorage.getPriority();

    if (priorityLocation != null) {
      lat = priorityLocation.lat;
      lon = priorityLocation.lon;
      cityName = priorityLocation.name;
    }

    _loadAllFromStorage();

    if (priorityLocation != null) {
      cityName = priorityLocation.name;
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
      cityName: cityName,
    );
  }

  Future<void> _fetchFreshData() async {
    try {
      final data = await WeatherService.fetchAllWeatherData(lat!, lon!);
      if (!mounted) return;
      setState(() {
        weatherData = data['weather'];
        forecastData = data['forecast'];
        airQualityData = data['airQuality'];
        cityName = weatherData!['name'];
        _showStatusToast = false;
      });
      _loadingManager.finishLoading(fromStorage: false);
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
          _loadingManager.setApiError();
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

  void _loadAllFromStorage() {
    final allData = _dataSystem.getAllCachedData();
    if (allData != null) {
      weatherData = allData['weather'];
      forecastData = allData['forecast'];
      airQualityData = allData['airQuality'];
      cityName = allData['city'] ?? 'Загрузка...';
      final timestamp = allData['timestamp'];
      if (timestamp != null && mounted) {
        try {
          final updateTime = DateTime.parse(timestamp.toString());
          _loadingManager.setLastUpdateTime(updateTime);
        } catch (_) {
          // Не удалось распарсить timestamp — некритично, пропускаем
        }
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

  Future<void> setLocation(
      double newLat, double newLon, String newCityName) async {
    setState(() {
      lat = newLat;
      lon = newLon;
      cityName = newCityName;
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
  }

  @override
  Widget build(BuildContext context) {
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
                      offset: _showCompactHeader
                          ? Offset.zero
                          : const Offset(0, -0.15),
                      duration: WeatherConst.durHeaderAnim,
                      curve: Curves.easeInOut,
                      child: CompactWeatherHeader(
                        cityName: cityName,
                        temp: weatherData!['main']['temp'].round(),
                        feelsLike: weatherData!['main']['feels_like'].round(),
                        iconCode: weatherData!['weather'][0]['icon'],
                        description:
                            weatherData!['weather'][0]['description'],
                        now: DateTime.now(),
                      ),
                    ),
                  ),
                ),
              ),
            if (_loadingManager.isRefreshing)
              const RepaintBoundary(child: LoadingOverlay()),
            if (_showStatusToast)
              RepaintBoundary(
                child: StatusToast(
                  isVisible: _showStatusToast,
                  title: _loadingManager.isApiError
                      ? 'Перебои API'
                      : 'Проблемы с подключением:(',
                  subtitle: _loadingManager.isApiError
                      ? 'Подождите когда API даст ответ, временные перебои. Используем сохранённые данные'
                      : 'Используем сохранённые данные',
                  icon: _loadingManager.isApiError
                      ? Icons.cloud_off
                      : Icons.wifi_off,
                  onDismiss: () =>
                      setState(() => _showStatusToast = false),
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
        isApiError: _loadingManager.isApiError,
      );
    }

    if (weatherData == null && _loadingManager.isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(color: WeatherConst.textPrimary),
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
                  _buildGlassCard(
                      'Почасовой прогноз', _buildHourlyForecast()),
                  const SizedBox(height: 12),
                  Container(
                      key: widget.tipsKey ?? _tipsKey,
                      child: _buildTipCard()),
                  const SizedBox(height: 12),
                  _buildGlassCard(
                      '5-дневный прогноз', _buildDailyForecast()),
                  const SizedBox(height: 12),
                  _buildSunCard(),
                  const SizedBox(height: 12),
                  _buildAirQualityCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMainWeatherCard() {
    if (weatherData == null) return const SizedBox.shrink();

    DateTime now = DateTime.now();
    double humidity = weatherData!['main']['humidity'].toDouble();
    double windSpeed = weatherData!['wind']['speed'].toDouble();
    double pressure = WeatherUtils.convertPressureToMmhg(
        weatherData!['main']['pressure'].toDouble());
    int temp = weatherData!['main']['temp'].round();
    int feelsLike = weatherData!['main']['feels_like'].round();
    String description = weatherData!['weather'][0]['description'];
    String iconCode = weatherData!['weather'][0]['icon'];
    String capitalizedDescription =
        description[0].toUpperCase() + description.substring(1);

    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius: BorderRadius.circular(WeatherConst.radiusCard),
          border: Border.all(
              color: WeatherConst.textPrimary.withValues(alpha: 0.12)),
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
                          Text(cityName,
                              style: WeatherConst.tsCityName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(WeatherUtils.formatDate(now),
                              style: WeatherConst.tsDateLabel),
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
                        borderRadius: BorderRadius.circular(
                            WeatherConst.radiusWeatherIconBg),
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
                Center(
                    child:
                        Text('$temp°', style: WeatherConst.tsHeroTemp)),
                const SizedBox(height: 8),
                Center(
                    child: Text(capitalizedDescription,
                        style: WeatherConst.tsDescription)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: _buildDetailCard(
                            value: '${humidity.round()}%',
                            label: 'Влажность',
                            color: WeatherConst.textPrimary)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildDetailCard(
                            value: '${windSpeed.round()} км/ч',
                            label:
                                'Ветер ${WeatherUtils.getWindDirection(weatherData!['wind']['deg'])}',
                            color: WeatherConst.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _buildDetailCard(
                            value: '${pressure.round()} мм',
                            label: 'Давление',
                            color: WeatherConst.textPrimary)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildDetailCard(
                            value: '$feelsLike°',
                            label: 'Ощущается',
                            color: WeatherConst.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      {required String value,
      required String label,
      required Color color}) {
    return Container(
      padding: WeatherConst.padDetailCard,
      decoration: BoxDecoration(
        color: WeatherConst.bgDetailCard,
        borderRadius:
            BorderRadius.circular(WeatherConst.radiusDetailCard),
        border: Border.all(
            color: WeatherConst.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(value,
              style: WeatherConst.tsDetailValue.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: WeatherConst.tsDetailLabel),
        ],
      ),
    );
  }

  Widget _buildGlassCard(String title, Widget child) {
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          border: Border.all(color: WeatherConst.bgCardLighter),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          child: Padding(
            padding: WeatherConst.padGlassCardContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.access_time,
                      color: WeatherConst.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(title, style: WeatherConst.tsGlassCardTitle),
                ]),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyForecast() {
    if (forecastData == null) return const SizedBox.shrink();
    List<dynamic> list = forecastData!['list'];
    List<Widget> hourlyWidgets = [];
    for (int i = 0; i < 8 && i < list.length; i++) {
      var item = list[i];
      DateTime time = DateTime.parse(item['dt_txt']);
      String hour = i == 0 ? 'Сейчас' : '${time.hour}:00';
      double temp = item['main']['temp'];
      String iconCode = item['weather'][0]['icon'];
      String shortDesc = WeatherUtils.getShortWeatherDescription(iconCode);
      hourlyWidgets.add(FadeInWrapper(
          duration: Duration(milliseconds: 300 + (i * 50)),
          offsetY: 20,
          child: _forecastItem(
              hour, shortDesc, iconCode, '${temp.round()}°')));
    }
    return Column(children: hourlyWidgets);
  }

  Widget _buildTipCard() {
    if (weatherData == null) return const SizedBox.shrink();
    final tip = _tipsSystem.analyzeWeatherForTips(weatherData, forecastData);
    if (tip != null && tip.isNotEmpty) {
      final isImportant = tip['type'] == 'rain' || tip['type'] == 'snow';
      return AnimatedTipCard(
          title: tip['title'],
          message: tip['message'],
          timeText: tip['time'],
          accentColor: tip['color'],
          icon: tip['icon'],
          isImportant: isImportant);
    }
    return const SizedBox.shrink();
  }

  Widget _buildDailyForecast() {
    if (forecastData == null) return const SizedBox.shrink();
    Map<String, Map<String, dynamic>> dailyForecast = {};
    List<dynamic> list = forecastData!['list'];
    for (var item in list) {
      String date = item['dt_txt'].split(' ')[0];
      if (!dailyForecast.containsKey(date) && dailyForecast.length < 5) {
        dailyForecast[date] = item;
      }
    }
    List<Widget> dailyWidgets = [];
    int index = 0;
    dailyForecast.forEach((date, item) {
      DateTime dateTime = DateTime.parse(date);
      String weekday = WeatherConst.daysOfWeekFull[dateTime.weekday % 7];
      double temp = item['main']['temp'];
      String iconCode = item['weather'][0]['icon'];
      String shortDesc = WeatherUtils.getShortWeatherDescription(iconCode);
      dailyWidgets.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (index * 50)),
          offsetY: 20,
          child: _forecastItem(
              weekday, shortDesc, iconCode, '${temp.round()}°',
              isDaily: true),
        ),
      );
      index++;
    });
    return Column(children: dailyWidgets);
  }

  Widget _forecastItem(String time, String desc, String iconCode,
      String temp,
      {bool isDaily = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: WeatherConst.padForecastItem,
      decoration: BoxDecoration(
        color: WeatherConst.bgForecastItem,
        borderRadius:
            BorderRadius.circular(WeatherConst.radiusForecastItem),
        border: Border.all(
            color: WeatherConst.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDaily ? 115 : 55,
            child: Text(time,
                style: WeatherConst.tsForecastTime
                    .copyWith(fontSize: isDaily ? 12 : 13),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(child: Text(desc, style: WeatherConst.tsForecastDesc)),
          Icon(WeatherUtils.getWeatherIcon(iconCode),
              color: WeatherConst.textPrimary,
              size: WeatherConst.forecastIconSize),
          const SizedBox(width: 12),
          Text(temp, style: WeatherConst.tsForecastTemp),
        ],
      ),
    );
  }

  Widget _buildSunCard() {
    if (weatherData == null) return const SizedBox.shrink();
    DateTime sunrise = DateTime.fromMillisecondsSinceEpoch(
        weatherData!['sys']['sunrise'] * 1000);
    DateTime sunset = DateTime.fromMillisecondsSinceEpoch(
        weatherData!['sys']['sunset'] * 1000);
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          border: Border.all(color: WeatherConst.bgCardLighter),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          child: Padding(
            padding: WeatherConst.padGlassCardContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.wb_sunny,
                      color: WeatherConst.accentSunYellow, size: 16),
                  const SizedBox(width: 8),
                  const Text('Солнце',
                      style: WeatherConst.tsGlassCardTitle),
                ]),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSunItem(
                        '${sunrise.hour.toString().padLeft(2, '0')}:${sunrise.minute.toString().padLeft(2, '0')}',
                        'Рассвет',
                        WeatherConst.accentSunYellow,
                        WeatherConst.accentSunOrange,
                      ),
                      _buildSunItem(
                        '${sunset.hour.toString().padLeft(2, '0')}:${sunset.minute.toString().padLeft(2, '0')}',
                        'Закат',
                        WeatherConst.accentSunsetRed,
                        WeatherConst.accentSunOrange,
                      ),
                    ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSunItem(
      String time, String label, Color color1, Color color2) {
    return Container(
      padding: WeatherConst.padSunItem,
      decoration: BoxDecoration(
        color: WeatherConst.bgSunItem,
        borderRadius:
            BorderRadius.circular(WeatherConst.radiusSunItem),
      ),
      child: Row(
        children: [
          Container(
            width: WeatherConst.sunDotSize,
            height: WeatherConst.sunDotSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color1, color2]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color1.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2)
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(time, style: WeatherConst.tsSunTime),
            Text(label, style: WeatherConst.tsSunLabel),
          ]),
        ],
      ),
    );
  }

  Widget _buildAirQualityCard() {
    if (airQualityData == null) return const SizedBox.shrink();
    int aqi = 2;
    String aqiText = 'Нет данных';
    Color aqiColor = Colors.grey;
    if (airQualityData!['list'] != null &&
        airQualityData!['list'].isNotEmpty) {
      aqi = airQualityData!['list'][0]['main']['aqi'];
      aqiText = WeatherUtils.getAirQualityText(aqi);
      aqiColor = WeatherUtils.getAirQualityColor(aqi);
    }
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          border: Border.all(color: WeatherConst.bgCardLighter),
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(WeatherConst.radiusGlassCard),
          child: Padding(
            padding: WeatherConst.padGlassCardContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.air,
                      color: WeatherConst.accentAir, size: 16),
                  const SizedBox(width: 8),
                  const Text('Качество воздуха',
                      style: WeatherConst.tsGlassCardTitle),
                ]),
                const SizedBox(height: 12),
                Center(
                    child: Column(children: [
                  Text(aqiText,
                      style: WeatherConst.tsAirQualityValue.copyWith(
                          color: aqiColor,
                          shadows: [
                            Shadow(
                                blurRadius: 6,
                                color:
                                    aqiColor.withValues(alpha: 0.4))
                          ])),
                  const SizedBox(height: 4),
                  const Text('Качество воздуха',
                      style: WeatherConst.tsAirQualityLabel),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== FADE IN WRAPPER ==========

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

class _FadeInWrapperState extends State<FadeInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
            begin: Offset(0, widget.offsetY / 100), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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