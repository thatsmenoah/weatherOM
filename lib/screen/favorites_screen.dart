import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/weather_service.dart';
import '../constants/favorites_const.dart';

// ========== МОДЕЛЬ ЛОКАЦИИ ==========

class FavoriteLocation {
  final String name;
  final String country;
  final double lat;
  final double lon;
  bool isFavorite;
  final bool isCurrent;

  FavoriteLocation({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    this.isFavorite = false,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'lat': lat,
        'lon': lon,
        'isFavorite': isFavorite,
      };

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) => FavoriteLocation(
        name: json['name'],
        country: json['country'],
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        isFavorite: json['isFavorite'] ?? false,
      );
}

// ========== СЕРВИС СОХРАНЕНИЯ (с кэшем в памяти) ==========

class FavoritesStorage {
  static const String _favoritesKey = 'favorites_locations';
  static const String _recentKey = 'recent_searches';
  static const String _priorityKey = 'priority_location';

  static List<FavoriteLocation>? _cachedFavorites;
  static FavoriteLocation? _cachedRecent;
  static FavoriteLocation? _cachedPriority;

  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();

    final favData = prefs.getString(_favoritesKey);
    if (favData != null) {
      final List<dynamic> decoded = json.decode(favData);
      _cachedFavorites = decoded.map((item) => FavoriteLocation.fromJson(item)).toList();
    } else {
      _cachedFavorites = [];
    }

    final recentData = prefs.getString(_recentKey);
    if (recentData != null) {
      _cachedRecent = FavoriteLocation.fromJson(json.decode(recentData));
    }

    final priorityData = prefs.getString(_priorityKey);
    if (priorityData != null) {
      _cachedPriority = FavoriteLocation.fromJson(json.decode(priorityData));
    }
  }

  static List<FavoriteLocation> getFavorites() => _cachedFavorites ?? [];
  static FavoriteLocation? getRecent() => _cachedRecent;
  static FavoriteLocation? getPriority() => _cachedPriority;

  static Future<void> saveFavorites(List<FavoriteLocation> favorites) async {
    _cachedFavorites = favorites;
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_favoritesKey, data);
  }

  static Future<void> saveRecentSearch(FavoriteLocation location) async {
    _cachedRecent = location;
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(location.toJson());
    await prefs.setString(_recentKey, data);
  }

  static Future<void> savePriority(FavoriteLocation? location) async {
    _cachedPriority = location;
    final prefs = await SharedPreferences.getInstance();
    if (location != null) {
      await prefs.setString(_priorityKey, json.encode(location.toJson()));
    } else {
      await prefs.remove(_priorityKey);
    }
  }

  static Future<void> clearAll() async {
    _cachedFavorites = [];
    _cachedRecent = null;
    _cachedPriority = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
    await prefs.remove(_recentKey);
    await prefs.remove(_priorityKey);
  }
}

// ========== ЭКРАН ИЗБРАННОГО ==========

class FavoritesScreen extends StatefulWidget {
  final Function(FavoriteLocation location)? onLocationSelected;
  final VoidCallback? onBackPressed;

  const FavoritesScreen({
    super.key,
    this.onLocationSelected,
    this.onBackPressed,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<FavoriteLocation> _searchResults = [];
  List<FavoriteLocation> _favorites = [];
  FavoriteLocation? _recentSearch;
  FavoriteLocation? _currentLocation;
  FavoriteLocation? _priorityLocation;

  bool _isSearching = false;
  bool _showSearchResults = false;

  final List<Map<String, dynamic>> _citiesDatabase = [
    // Россия
    {'name': 'Москва', 'country': 'Россия', 'lat': 55.7558, 'lon': 37.6173},
    {'name': 'Санкт-Петербург', 'country': 'Россия', 'lat': 59.9343, 'lon': 30.3351},
    {'name': 'Новосибирск', 'country': 'Россия', 'lat': 55.0084, 'lon': 82.9357},
    {'name': 'Екатеринбург', 'country': 'Россия', 'lat': 56.8389, 'lon': 60.6057},
    {'name': 'Казань', 'country': 'Россия', 'lat': 55.7961, 'lon': 49.1064},
    {'name': 'Нижний Новгород', 'country': 'Россия', 'lat': 56.2965, 'lon': 43.9361},
    {'name': 'Челябинск', 'country': 'Россия', 'lat': 55.1644, 'lon': 61.4368},
    {'name': 'Самара', 'country': 'Россия', 'lat': 53.1959, 'lon': 50.1002},
    {'name': 'Омск', 'country': 'Россия', 'lat': 54.9893, 'lon': 73.3682},
    {'name': 'Ростов-на-Дону', 'country': 'Россия', 'lat': 47.2357, 'lon': 39.7015},
    {'name': 'Уфа', 'country': 'Россия', 'lat': 54.7388, 'lon': 55.9721},
    {'name': 'Красноярск', 'country': 'Россия', 'lat': 56.0106, 'lon': 92.8526},
    {'name': 'Воронеж', 'country': 'Россия', 'lat': 51.6720, 'lon': 39.1844},
    {'name': 'Пермь', 'country': 'Россия', 'lat': 58.0105, 'lon': 56.2502},
    {'name': 'Волгоград', 'country': 'Россия', 'lat': 48.7080, 'lon': 44.5133},
    {'name': 'Саратов', 'country': 'Россия', 'lat': 51.5336, 'lon': 46.0343},
    {'name': 'Тюмень', 'country': 'Россия', 'lat': 57.1522, 'lon': 65.5272},
    {'name': 'Тольятти', 'country': 'Россия', 'lat': 53.5303, 'lon': 49.3461},
    {'name': 'Ижевск', 'country': 'Россия', 'lat': 56.8498, 'lon': 53.2045},
    {'name': 'Барнаул', 'country': 'Россия', 'lat': 53.3480, 'lon': 83.7765},
    {'name': 'Ульяновск', 'country': 'Россия', 'lat': 54.3142, 'lon': 48.4031},
    {'name': 'Иркутск', 'country': 'Россия', 'lat': 52.2860, 'lon': 104.2807},
    {'name': 'Хабаровск', 'country': 'Россия', 'lat': 48.4802, 'lon': 135.0719},
    {'name': 'Ярославль', 'country': 'Россия', 'lat': 57.6261, 'lon': 39.8845},
    {'name': 'Владивосток', 'country': 'Россия', 'lat': 43.1155, 'lon': 131.8855},
    {'name': 'Махачкала', 'country': 'Россия', 'lat': 42.9849, 'lon': 47.5047},
    {'name': 'Томск', 'country': 'Россия', 'lat': 56.4846, 'lon': 84.9476},
    {'name': 'Оренбург', 'country': 'Россия', 'lat': 51.7682, 'lon': 55.0969},
    {'name': 'Кемерово', 'country': 'Россия', 'lat': 55.3549, 'lon': 86.0868},
    {'name': 'Сочи', 'country': 'Россия', 'lat': 43.5855, 'lon': 39.7231},
    {'name': 'Севастополь', 'country': 'Россия', 'lat': 44.6167, 'lon': 33.5254},
    {'name': 'Симферополь', 'country': 'Россия', 'lat': 44.9521, 'lon': 34.1024},
    {'name': 'Балаклава', 'country': 'Россия', 'lat': 44.4954, 'lon': 33.5972},
    {'name': 'Гай', 'country': 'Россия', 'lat': 51.4667, 'lon': 58.4500},
    {'name': 'Орёл', 'country': 'Россия', 'lat': 52.9651, 'lon': 36.0785},
    {'name': 'Тверь', 'country': 'Россия', 'lat': 56.8587, 'lon': 35.9176},
    // Европа
    {'name': 'Минск', 'country': 'Беларусь', 'lat': 53.9006, 'lon': 27.5590},
    {'name': 'Киев', 'country': 'Украина', 'lat': 50.4501, 'lon': 30.5234},
    {'name': 'Херсон', 'country': 'Украина', 'lat': 46.6354, 'lon': 32.6169},
    {'name': 'Лондон', 'country': 'Великобритания', 'lat': 51.5074, 'lon': -0.1278},
    {'name': 'Париж', 'country': 'Франция', 'lat': 48.8566, 'lon': 2.3522},
    {'name': 'Берлин', 'country': 'Германия', 'lat': 52.5200, 'lon': 13.4050},
    {'name': 'Рим', 'country': 'Италия', 'lat': 41.9028, 'lon': 12.4964},
    {'name': 'Мадрид', 'country': 'Испания', 'lat': 40.4168, 'lon': -3.7038},
    {'name': 'Прага', 'country': 'Чехия', 'lat': 50.0755, 'lon': 14.4378},
    {'name': 'Варшава', 'country': 'Польша', 'lat': 52.2297, 'lon': 21.0122},
    {'name': 'Амстердам', 'country': 'Нидерланды', 'lat': 52.3676, 'lon': 4.9041},
    {'name': 'Стокгольм', 'country': 'Швеция', 'lat': 59.3293, 'lon': 18.0686},
    // Азия
    {'name': 'Пекин', 'country': 'Китай', 'lat': 39.9042, 'lon': 116.4074},
    {'name': 'Шанхай', 'country': 'Китай', 'lat': 31.2304, 'lon': 121.4737},
    {'name': 'Токио', 'country': 'Япония', 'lat': 35.6762, 'lon': 139.6503},
    {'name': 'Хиросима', 'country': 'Япония', 'lat': 34.3853, 'lon': 132.4553},
    {'name': 'Сеул', 'country': 'Южная Корея', 'lat': 37.5665, 'lon': 126.9780},
    {'name': 'Дели', 'country': 'Индия', 'lat': 28.6139, 'lon': 77.2090},
    {'name': 'Мумбаи', 'country': 'Индия', 'lat': 19.0760, 'lon': 72.8777},
    {'name': 'Бангкок', 'country': 'Таиланд', 'lat': 13.7563, 'lon': 100.5018},
    {'name': 'Сингапур', 'country': 'Сингапур', 'lat': 1.3521, 'lon': 103.8198},
    {'name': 'Дубай', 'country': 'ОАЭ', 'lat': 25.2048, 'lon': 55.2708},
    {'name': 'Стамбул', 'country': 'Турция', 'lat': 41.0082, 'lon': 28.9784},
    // Америка
    {'name': 'Нью-Йорк', 'country': 'США', 'lat': 40.7128, 'lon': -74.0060},
    {'name': 'Лос-Анджелес', 'country': 'США', 'lat': 34.0522, 'lon': -118.2437},
    {'name': 'Чикаго', 'country': 'США', 'lat': 41.8781, 'lon': -87.6298},
    {'name': 'Торонто', 'country': 'Канада', 'lat': 43.6532, 'lon': -79.3832},
    {'name': 'Мехико', 'country': 'Мексика', 'lat': 19.4326, 'lon': -99.1332},
    {'name': 'Сан-Паулу', 'country': 'Бразилия', 'lat': -23.5505, 'lon': -46.6333},
    {'name': 'Буэнос-Айрес', 'country': 'Аргентина', 'lat': -34.6037, 'lon': -58.3816},
    // Африка
    {'name': 'Каир', 'country': 'Египет', 'lat': 30.0444, 'lon': 31.2357},
    {'name': 'Кейптаун', 'country': 'ЮАР', 'lat': -33.9241, 'lon': 18.4241},
    {'name': 'Лагос', 'country': 'Нигерия', 'lat': 6.5244, 'lon': 3.3792},
    // Австралия и Океания
    {'name': 'Сидней', 'country': 'Австралия', 'lat': -33.8688, 'lon': 151.2093},
    {'name': 'Мельбурн', 'country': 'Австралия', 'lat': -37.8136, 'lon': 144.9631},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _favorites = FavoritesStorage.getFavorites();
    _recentSearch = FavoritesStorage.getRecent();
    _priorityLocation = FavoritesStorage.getPriority();

    _currentLocation = FavoriteLocation(
      name: 'Определение...',
      country: 'Россия',
      lat: 55.7558,
      lon: 37.6173,
      isCurrent: true,
    );

    _getRealLocation();
  }

  Future<void> _getRealLocation() async {
    try {
      final position = await WeatherService.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _currentLocation = FavoriteLocation(
          name: 'Определение...',
          country: 'Россия',
          lat: position.latitude,
          lon: position.longitude,
          isCurrent: true,
        );
      });

      String cityName = 'Текущее местоположение';
      try {
        final data = await WeatherService.fetchAllWeatherData(position.latitude, position.longitude);
        cityName = data['weather']['name'] ?? cityName;
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _currentLocation = FavoriteLocation(
          name: cityName,
          country: 'Россия',
          lat: position.latitude,
          lon: position.longitude,
          isCurrent: true,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentLocation = FavoriteLocation(
          name: 'Москва',
          country: 'Россия',
          lat: 55.7558,
          lon: 37.6173,
          isCurrent: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _isSearching = query.isNotEmpty;
      _showSearchResults = query.isNotEmpty;

      if (query.isNotEmpty) {
        _searchResults = _citiesDatabase
            .where((city) => city['name'].toString().toLowerCase().contains(query))
            .map((city) => FavoriteLocation(
                  name: city['name'],
                  country: city['country'],
                  lat: (city['lat'] as num).toDouble(),
                  lon: (city['lon'] as num).toDouble(),
                  isFavorite: _favorites.any((f) => f.name == city['name'] && f.lat == city['lat']),
                ))
            .toList();
      } else {
        _searchResults = [];
      }
    });
  }

  void _selectLocation(FavoriteLocation location) {
    HapticFeedback.mediumImpact();

    if (!location.isCurrent) {
      setState(() {
        _recentSearch = FavoriteLocation(
          name: location.name,
          country: location.country,
          lat: location.lat,
          lon: location.lon,
          isFavorite: _favorites.any((f) => f.name == location.name && f.lat == location.lat),
        );
      });

      FavoritesStorage.saveRecentSearch(_recentSearch!);
    }

    widget.onLocationSelected?.call(location);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleFavorite(FavoriteLocation location) {
    if (location.isCurrent) return;

    HapticFeedback.lightImpact();

    setState(() {
      final index = _favorites.indexWhere((f) => f.name == location.name && f.lat == location.lat);

      if (index >= 0) {
        _favorites.removeAt(index);
      } else {
        _favorites.add(FavoriteLocation(
          name: location.name,
          country: location.country,
          lat: location.lat,
          lon: location.lon,
          isFavorite: true,
        ));
      }

      if (_recentSearch != null && _recentSearch!.name == location.name && _recentSearch!.lat == location.lat) {
        _recentSearch!.isFavorite = _favorites.any((f) => f.name == location.name && f.lat == location.lat);
      }

      final searchIndex = _searchResults.indexWhere((s) => s.name == location.name && s.lat == location.lat);
      if (searchIndex >= 0) {
        _searchResults[searchIndex].isFavorite = _favorites.any((f) => f.name == location.name && f.lat == location.lat);
      }
    });

    FavoritesStorage.saveFavorites(_favorites);
    if (_recentSearch != null) {
      FavoritesStorage.saveRecentSearch(_recentSearch!);
    }
  }

  void _togglePriority(FavoriteLocation location) {
    if (location.isCurrent) return;

    HapticFeedback.heavyImpact();

    setState(() {
      if (_priorityLocation != null && _priorityLocation!.name == location.name && _priorityLocation!.lat == location.lat) {
        _priorityLocation = null;
        FavoritesStorage.savePriority(null);
      } else {
        _priorityLocation = FavoriteLocation(
          name: location.name,
          country: location.country,
          lat: location.lat,
          lon: location.lon,
          isFavorite: true,
        );
        FavoritesStorage.savePriority(_priorityLocation);

        final favIndex = _favorites.indexWhere((f) => f.name == location.name && f.lat == location.lat);
        if (favIndex < 0) {
          _favorites.add(FavoriteLocation(
            name: location.name,
            country: location.country,
            lat: location.lat,
            lon: location.lon,
            isFavorite: true,
          ));
          FavoritesStorage.saveFavorites(_favorites);
        }
      }
    });
  }

  bool _isPriority(FavoriteLocation location) {
    return _priorityLocation != null &&
        _priorityLocation!.name == location.name &&
        _priorityLocation!.lat == location.lat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(color: FavoritesConst.bgScreen),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _showSearchResults && _isSearching ? _buildSearchResults() : _buildMainList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: FavoritesConst.padHeader,
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBackPressed ?? () => Navigator.pop(context),
            child: Container(
              width: FavoritesConst.headerButtonSize,
              height: FavoritesConst.headerButtonSize,
              decoration: BoxDecoration(
                color: FavoritesConst.bgHeaderButton,
                borderRadius: BorderRadius.circular(FavoritesConst.radiusHeaderButton),
                border: favoritesDefaultBorder01(),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: FavoritesConst.textPrimary, size: FavoritesConst.headerIconSize),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Избранное', style: FavoritesConst.tsHeaderTitle)),
          if (_isSearching)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
              child: Container(
                width: FavoritesConst.headerButtonSize,
                height: FavoritesConst.headerButtonSize,
                decoration: BoxDecoration(
                  color: FavoritesConst.bgHeaderButton,
                  borderRadius: BorderRadius.circular(FavoritesConst.radiusHeaderButton),
                ),
                child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6), size: FavoritesConst.headerCloseIconSize),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: FavoritesConst.padSearchBar,
      child: Container(
        height: FavoritesConst.searchBarHeight,
        decoration: BoxDecoration(
          color: FavoritesConst.bgSearchBar,
          borderRadius: BorderRadius.circular(FavoritesConst.radiusSearchBar),
          border: _searchFocusNode.hasFocus ? favoritesFocusedBorder() : favoritesDefaultBorder(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FavoritesConst.radiusSearchBar),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: FavoritesConst.blurSearchBar, sigmaY: FavoritesConst.blurSearchBar),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: FavoritesConst.tsSearchInput,
              cursorColor: FavoritesConst.textCursor,
              decoration: InputDecoration(
                hintText: 'Поиск города...',
                hintStyle: FavoritesConst.tsSearchHint,
                prefixIcon: Icon(Icons.search_rounded, color: FavoritesConst.textSearchIcon, size: FavoritesConst.searchIconSize),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: FavoritesConst.padMainList,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentLocation != null) ...[
              _buildSectionHeader('Текущее местоположение'),
              const SizedBox(height: 8),
              _buildCurrentLocationCard(_currentLocation!),
              const SizedBox(height: 24),
            ],
            if (_recentSearch != null) ...[
              _buildSectionHeader('Недавно искали'),
              const SizedBox(height: 8),
              _buildLocationCard(location: _recentSearch!, showStar: true, showPriority: true),
              const SizedBox(height: 24),
            ],
            _buildSectionHeader('Избранные локации'),
            const SizedBox(height: 8),
            if (_favorites.isEmpty)
              _buildEmptyState()
            else
              ..._favorites.map((location) => _buildLocationCard(location: location, showStar: true, showPriority: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.favorite_outline_rounded, color: Colors.white.withValues(alpha: 0.15), size: FavoritesConst.emptyIconSize),
            const SizedBox(height: 16),
            Text('Нет избранных локаций', style: FavoritesConst.tsEmptyTitle),
            const SizedBox(height: 6),
            Text('Используйте поиск, чтобы добавить город', style: FavoritesConst.tsEmptySubtitle),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, color: FavoritesConst.textVeryDim, size: FavoritesConst.emptySearchIconSize),
            const SizedBox(height: 12),
            Text('Город не найден', style: FavoritesConst.tsSearchEmpty),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: FavoritesConst.padMainList,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Результаты поиска'),
            const SizedBox(height: 8),
            ..._searchResults.map((location) => _buildLocationCard(location: location, showStar: true, showPriority: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: FavoritesConst.tsSectionHeader),
    );
  }

  Widget _buildCurrentLocationCard(FavoriteLocation location) {
    return FadeInWrapper(
      duration: FavoritesConst.durCardFadeCurrent,
      offsetY: 10,
      child: GestureDetector(
        onTap: () => _selectLocation(location),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: FavoritesConst.bgCard,
            borderRadius: BorderRadius.circular(FavoritesConst.radiusCard),
            border: favoritesBlueBorder(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FavoritesConst.radiusCard),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: FavoritesConst.blurCard, sigmaY: FavoritesConst.blurCard),
              child: Padding(
                padding: FavoritesConst.padCardContent,
                child: Row(
                  children: [
                    Container(
                      width: FavoritesConst.cardIconBoxSize,
                      height: FavoritesConst.cardIconBoxSize,
                      decoration: BoxDecoration(
                        color: FavoritesConst.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(FavoritesConst.radiusIconBox),
                      ),
                      child: const Icon(Icons.near_me_rounded, color: FavoritesConst.accentBlue, size: FavoritesConst.cardIconSize),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(location.name, style: FavoritesConst.tsLocationName),
                          const SizedBox(height: 2),
                          Text(location.country, style: FavoritesConst.tsLocationCountry),
                        ],
                      ),
                    ),
                    Container(
                      padding: FavoritesConst.padBadge,
                      decoration: BoxDecoration(
                        color: FavoritesConst.bgBadge,
                        borderRadius: BorderRadius.circular(FavoritesConst.radiusBadge),
                      ),
                      child: Text('Сейчас', style: FavoritesConst.tsBadgeText),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.star_outline_rounded, color: FavoritesConst.textVeryDim2, size: FavoritesConst.actionIconSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
    required FavoriteLocation location,
    bool showStar = true,
    bool showPriority = false,
  }) {
    final isFav = _favorites.any((f) => f.name == location.name && f.lat == location.lat);
    final isPriority = _isPriority(location);

    return FadeInWrapper(
      duration: FavoritesConst.durCardFade,
      offsetY: 20,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => _selectLocation(location),
          child: Container(
            decoration: BoxDecoration(
              color: FavoritesConst.bgCardSecondary,
              borderRadius: BorderRadius.circular(FavoritesConst.radiusCard),
              border: isPriority ? favoritesRedBorder() : favoritesDefaultBorder(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FavoritesConst.radiusCard),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: FavoritesConst.blurSearchBar, sigmaY: FavoritesConst.blurSearchBar),
                child: Padding(
                  padding: FavoritesConst.padCardContent,
                  child: Row(
                    children: [
                      Container(
                        width: FavoritesConst.cardIconBoxSize,
                        height: FavoritesConst.cardIconBoxSize,
                        decoration: BoxDecoration(
                          color: isPriority ? FavoritesConst.accentRed.withValues(alpha: 0.1) : FavoritesConst.bgIconBox,
                          borderRadius: BorderRadius.circular(FavoritesConst.radiusIconBox),
                        ),
                        child: Icon(
                          isPriority ? Icons.push_pin_rounded : Icons.location_on_outlined,
                          color: isPriority ? FavoritesConst.accentRed : FavoritesConst.textPrimary,
                          size: FavoritesConst.cardIconSize,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(child: Text(location.name, style: FavoritesConst.tsLocationName)),
                                if (isPriority) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: FavoritesConst.padPriorityBadge,
                                    decoration: BoxDecoration(
                                      color: FavoritesConst.bgPriorityBadge,
                                      borderRadius: BorderRadius.circular(FavoritesConst.radiusPriorityBadge),
                                    ),
                                    child: const Text('Приоритет', style: FavoritesConst.tsPriorityBadgeText),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(location.country, style: FavoritesConst.tsLocationCountry),
                          ],
                        ),
                      ),
                      if (showStar && !location.isCurrent) ...[
                        GestureDetector(
                          onTap: () => _togglePriority(location),
                          child: Container(
                            width: FavoritesConst.actionButtonSize,
                            height: FavoritesConst.actionButtonSize,
                            decoration: BoxDecoration(
                              color: isPriority ? FavoritesConst.bgPriorityBadge : FavoritesConst.bgIconBoxWhite,
                              borderRadius: BorderRadius.circular(FavoritesConst.radiusActionButton),
                            ),
                            child: Icon(
                              Icons.priority_high_rounded,
                              color: isPriority ? FavoritesConst.accentRed : FavoritesConst.textVeryDim2,
                              size: FavoritesConst.actionIconSize,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _toggleFavorite(location),
                          child: Container(
                            width: FavoritesConst.actionButtonSize,
                            height: FavoritesConst.actionButtonSize,
                            decoration: BoxDecoration(
                              color: FavoritesConst.bgIconBoxWhite,
                              borderRadius: BorderRadius.circular(FavoritesConst.radiusActionButton),
                            ),
                            child: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFav ? FavoritesConst.accentGold : FavoritesConst.textVeryDim2,
                              size: FavoritesConst.actionIconSize,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ ==========

class FadeInWrapper extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;
  final Curve curve;

  const FadeInWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offsetY = 0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, offsetY * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}