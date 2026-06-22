import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/data_system.dart';
import '../core/tips_system.dart';
import '../core/loading_system.dart';
import '../services/weather_service.dart';
import '../utils/weather_utils.dart';
import '../screen/favorites_screen.dart'; 

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
        duration: const Duration(seconds: 2),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(height: 2, color: widget.accentColor.withValues(alpha: 0.4)),
            ),
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: widget.accentColor.withValues(alpha: 0.15)),
                      ),
                      child: Center(child: Icon(widget.icon, color: widget.accentColor, size: 22)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.accentColor)),
                          const SizedBox(height: 2),
                          Text(widget.message, style: const TextStyle(fontSize: 11, color: Color(0xFFa0a0a0))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(widget.timeText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: widget.accentColor.withValues(alpha: 0.8))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isImportant) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.accentColor.withValues(alpha: 0.2 + _pulseController.value * 0.2), width: 1),
          ),
          child: card,
        ),
      );
    }

    return FadeInWrapper(duration: const Duration(milliseconds: 400), offsetY: 10, child: card);
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _loadingManager.dispose();
    super.dispose();
  }

  // ========== НОВАЯ ЛОГИКА ИНИЦИАЛИЗАЦИИ ==========
  
 Future<void> _initializeApp() async {
    // 1. Загружаем данные из хранилища
    await _dataSystem.init();
    
    // 2. Проверяем приоритетный город ДО загрузки кэша
    final priorityLocation = FavoritesStorage.getPriority();
    
    if (priorityLocation != null) {
      // Если есть приоритетный город — используем его координаты
      lat = priorityLocation.lat;
      lon = priorityLocation.lon;
      cityName = priorityLocation.name;
    }
    
    // 3. Загружаем кэшированные данные
    _loadAllFromStorage(); // finishLoading уже вызывается внутри если данные есть
    
    // 4. Если есть приоритетный город — перезаписываем название
    if (priorityLocation != null) {
      cityName = priorityLocation.name;
    }
    
    // 5. Если данных нет — показываем загрузку
    if (weatherData == null) {
      _loadingManager.startLoading();
    }
    
    // Обновляем UI
    if (mounted) setState(() {});
    
    // 6. В фоне пробуем обновить данные с API
    _updateWeatherInBackground();
}

  Future<void> _updateWeatherInBackground() async {
    try {
      // Если координаты уже установлены из приоритетного города — не перезаписываем
      if (lat == null || lon == null) {
        final position = await WeatherService.getCurrentPosition();
        
        if (!mounted) return;
        
        lat = position.latitude;
        lon = position.longitude;
      }
    } catch (e) {
      // Ошибка геолокации - используем приоритетный город или Москву
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
    
    // Пробуем загрузить свежие данные
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
      
      // Ошибка API или нет интернета
      if (weatherData != null) {
        // Есть кэшированные данные
        setState(() => _showStatusToast = true);
        
        // Проверяем тип ошибки
        if (e.toString().contains('SocketException') || 
            e.toString().contains('HandshakeException') ||
            e.toString().contains('HttpException')) {
          // Нет интернета
          _loadingManager.setOfflineMode();
        } else {
          // Ошибка API
          _loadingManager.setApiError();
        }
      } else {
        // Вообще нет данных
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
    
    // ✅ Проверяем, есть ли timestamp
    final timestamp = allData['timestamp'];
    if (timestamp != null && mounted) {
      try {
        final updateTime = DateTime.parse(timestamp.toString());
        _loadingManager.setLastUpdateTime(updateTime);
      } catch (e) {
        // Если не удалось распарсить — игнорируем
      }
    }
    
    // ✅ Убираем finishLoading отсюда - он вызывается в _initializeApp
    if (mounted) setState(() {});
  }
}
  // ========== ПУБЛИЧНЫЕ МЕТОДЫ ==========

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> setLocation(double newLat, double newLon, String newCityName) async {
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
      // Проверяем приоритетный город при ошибке геолокации
      if (!mounted) return;
      
      final priorityLocation = FavoritesStorage.getPriority();
      if (priorityLocation != null) {
        lat = priorityLocation.lat;
        lon = priorityLocation.lon;
      } else {
        // Фоллбэк на Москву только если нет приоритетного города
        lat ??= 55.7558;
        lon ??= 37.6173;
      }
    }
    
    await _fetchFreshData();
}

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0f0f0f), Color(0xFF1a1a1a)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            if (_loadingManager.isRefreshing)
              const LoadingOverlay(),
            if (_showStatusToast)
  StatusToast(
    isVisible: _showStatusToast,
    title: _loadingManager.isApiError ? 'Перебои API' : 'Проблемы с подключением:(',
    subtitle: _loadingManager.isApiError 
        ? 'Подождите когда API даст ответ, временные перебои. Используем сохранённые данные'
        : 'Используем сохранённые данные',
    icon: _loadingManager.isApiError ? Icons.cloud_off : Icons.wifi_off,
    onDismiss: () => setState(() => _showStatusToast = false),
  ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Если нет данных и есть ошибка
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
    
    // Если нет данных и загрузка
    if (weatherData == null && _loadingManager.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    // Если данные есть - показываем контент
    if (weatherData != null) {
      return RefreshIndicator(
        onRefresh: _refreshWeather,
        color: Colors.white,
        child: ScrollConfiguration(
          behavior: NoGlowBehavior(),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 30),
              child: Column(
                children: [
                  _buildMainWeatherCard(),
                  const SizedBox(height: 12),
                  _buildGlassCard('Почасовой прогноз', _buildHourlyForecast()),
                  const SizedBox(height: 12),
                  Container(key: widget.tipsKey ?? _tipsKey, child: _buildTipCard()),
                  const SizedBox(height: 12),
                  _buildGlassCard('5-дневный прогноз', _buildDailyForecast()),
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
    double pressure = WeatherUtils.convertPressureToMmhg(weatherData!['main']['pressure'].toDouble());
    int temp = weatherData!['main']['temp'].round();
    int feelsLike = weatherData!['main']['feels_like'].round();
    String description = weatherData!['weather'][0]['description'];
    String iconCode = weatherData!['weather'][0]['icon'];
    
    // Делаем описание с заглавной буквы
    String capitalizedDescription = description[0].toUpperCase() + description.substring(1);
    
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cityName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(WeatherUtils.formatDate(now), style: const TextStyle(fontSize: 13, color: Color(0xFFa0a0a0), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            UpdateTimeIndicator(
  updateTime: _loadingManager.lastUpdateTime,
  isFromCache: _loadingManager.isUsingStorage,
)
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Icon(WeatherUtils.getWeatherIcon(iconCode), color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(child: Text('$temp°', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(blurRadius: 12, color: Colors.black26)]))),
                  const SizedBox(height: 8),
                  // ОПИСАНИЕ ПОГОДЫ - БЕЛОЕ, ЖИРНОЕ, С ЗАГЛАВНОЙ БУКВЫ, ЧУТЬ МЕНЬШЕ
                  Center(
                    child: Text(
                      capitalizedDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDetailCard(value: '${humidity.round()}%', label: 'Влажность', color: const Color(0xFF10b981))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDetailCard(value: '${windSpeed.round()} км/ч', label: 'Ветер ${WeatherUtils.getWindDirection(weatherData!['wind']['deg'])}', color: const Color(0xFFef4444))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDetailCard(value: '${pressure.round()} мм', label: 'Давление', color: const Color(0xFF3b82f6))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDetailCard(value: '$feelsLike°', label: 'Ощущается', color: Colors.white)),
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

// КАРТОЧКИ БОЛЬШЕ, ЖИРНЕЕ, НАДПИСЬ БЛИЖЕ К ПОКАЗАНИЮ
Widget _buildDetailCard({required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2), // Было 8, теперь ближе
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFa0a0a0),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(String title, Widget child) {
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.access_time, color: Color(0xFFa0a0a0), size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
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
      
      hourlyWidgets.add(FadeInWrapper(duration: Duration(milliseconds: 300 + (i * 50)), offsetY: 20, child: _forecastItem(hour, shortDesc, iconCode, '${temp.round()}°')));
    }
    
    return Column(children: hourlyWidgets);
  }

  Widget _buildTipCard() {
    if (weatherData == null) return const SizedBox.shrink();
    
    final tip = _tipsSystem.analyzeWeatherForTips(weatherData, forecastData);
    
    if (tip != null && tip.isNotEmpty) {
      final isImportant = tip['type'] == 'rain' || tip['type'] == 'snow';
      return AnimatedTipCard(title: tip['title'], message: tip['message'], timeText: tip['time'], accentColor: tip['color'], icon: tip['icon'], isImportant: isImportant);
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
    
    List<String> weekdaysFull = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
    List<Widget> dailyWidgets = [];
    int index = 0;
    
    dailyForecast.forEach((date, item) {
      DateTime dateTime = DateTime.parse(date);
      String weekday = weekdaysFull[dateTime.weekday % 7];
      double temp = item['main']['temp'];
      String iconCode = item['weather'][0]['icon'];
      String shortDesc = WeatherUtils.getShortWeatherDescription(iconCode);
      
      dailyWidgets.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (index * 50)),
          offsetY: 20,
          child: _forecastItem(weekday, shortDesc, iconCode, '${temp.round()}°', isDaily: true),
        ),
      );
      index++;
    });
    
    return Column(children: dailyWidgets);
  }

  Widget _forecastItem(String time, String desc, String iconCode, String temp, {bool isDaily = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDaily ? 115 : 55,
            child: Text(
              time,
              style: TextStyle(
                fontSize: isDaily ? 12 : 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(fontSize: 12, color: Color(0xFFa0a0a0)),
            ),
          ),
          Icon(WeatherUtils.getWeatherIcon(iconCode), color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            temp,
            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSunCard() {
    if (weatherData == null) return const SizedBox.shrink();
    
    DateTime sunrise = DateTime.fromMillisecondsSinceEpoch(weatherData!['sys']['sunrise'] * 1000);
    DateTime sunset = DateTime.fromMillisecondsSinceEpoch(weatherData!['sys']['sunset'] * 1000);
    
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.wb_sunny, color: Color(0xFFffd700), size: 16), const SizedBox(width: 8), const Text('Солнце', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _buildSunItem('${sunrise.hour.toString().padLeft(2, '0')}:${sunrise.minute.toString().padLeft(2, '0')}', 'Рассвет', const Color(0xFFffd700), const Color(0xFFff8c00)),
                    _buildSunItem('${sunset.hour.toString().padLeft(2, '0')}:${sunset.minute.toString().padLeft(2, '0')}', 'Закат', const Color(0xFFff6b6b), const Color(0xFFff8c00)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSunItem(String time, String label, Color color1, Color color2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color1, color2]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: color1.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFa0a0a0), fontWeight: FontWeight.w500))]),
        ],
      ),
    );
  }

  Widget _buildAirQualityCard() {
    if (airQualityData == null) return const SizedBox.shrink();
    
    int aqi = 2;
    String aqiText = 'Нет данных';
    Color aqiColor = Colors.grey;
    
    if (airQualityData!['list'] != null && airQualityData!['list'].isNotEmpty) {
      aqi = airQualityData!['list'][0]['main']['aqi'];
      aqiText = WeatherUtils.getAirQualityText(aqi);
      aqiColor = WeatherUtils.getAirQualityColor(aqi);
    }
    
    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.air, color: Color(0xFF4ecdc4), size: 16), const SizedBox(width: 8), const Text('Качество воздуха', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]),
                  const SizedBox(height: 12),
                  Center(child: Column(children: [
                    Text(aqiText, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: aqiColor, shadows: [Shadow(blurRadius: 6, color: aqiColor.withValues(alpha: 0.4))])),
                    const SizedBox(height: 4),
                    const Text('Качество воздуха', style: TextStyle(fontSize: 12, color: Color(0xFFa0a0a0))),
                  ])),
                ],
              ),
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
    this.duration = const Duration(milliseconds: 400),
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
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}