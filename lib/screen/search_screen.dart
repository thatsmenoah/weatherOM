import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/settings_const.dart';
import '../core/locale_manager.dart';

class SearchScreen extends StatefulWidget {
  final Function(double lat, double lon, String name)? onLocationSelected;

  const SearchScreen({super.key, this.onLocationSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _LocationEntry {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;

  const _LocationEntry({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  factory _LocationEntry.fromMap(Map<String, dynamic> map) {
    return _LocationEntry(
      name: map['name']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'subtitle': subtitle,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get fullName => subtitle.isEmpty ? name : '$name, $subtitle';
}

class _SearchScreenState extends State<SearchScreen>
  with SingleTickerProviderStateMixin {
  static const _favoritesKey = 'favorite_locations';
  static const _recentKey = 'recent_locations';

  final LocaleManager _localeManager = LocaleManager();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final AnimationController _favoritesController;

  List<_LocationEntry> _results = [];
  List<_LocationEntry> _favorites = [];
  List<_LocationEntry> _recent = [];
  bool _isLoading = false;
  bool _isFavoritesOpen = false;
  bool _isFavoritesMounted = false;
  String? _errorMessage;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _favoritesController = AnimationController(
      duration: const Duration(milliseconds: 370),
      vsync: this,
    );
    _loadSavedLocations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    _favoritesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = _decodeEntries(prefs.getString(_favoritesKey));
    final recent = _decodeEntries(prefs.getString(_recentKey));
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _recent = recent;
    });
  }

  List<_LocationEntry> _decodeEntries(String? value) {
    if (value == null || value.isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => _LocationEntry.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(_favorites.map((item) => item.toMap()).toList()),
    );
    await prefs.setString(
      _recentKey,
      jsonEncode(_recent.map((item) => item.toMap()).toList()),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      if (_results.isNotEmpty || _errorMessage != null) {
        setState(() {
          _results = [];
          _errorMessage = null;
        });
      }
      return;
    }
    _searchLocations(query);
  }

  Future<void> _searchLocations(String query) async {
    final requestId = ++_searchRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final language = _localeManager.currentLocale == 'Русский' ? 'ru' : 'en';
      final uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {
          'name': query,
          'count': '8',
          'language': language,
          'format': 'json',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Geocoding returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final rawResults = data is Map ? data['results'] : null;
      final results = rawResults is List
          ? rawResults.whereType<Map>().map(_fromApiResult).toList()
          : <_LocationEntry>[];

        if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
        if (results.isEmpty) {
          _errorMessage = _localeManager.getText('city_not_found');
        }
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _results = [];
        _errorMessage = _localeManager.getText('no_internet');
      });
    }
  }

  _LocationEntry _fromApiResult(Map result) {
    final admin = result['admin1']?.toString() ?? '';
    final country = result['country']?.toString() ?? '';
    final subtitle = [admin, country]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    return _LocationEntry(
      name: result['name']?.toString() ?? '',
      subtitle: subtitle,
      latitude: (result['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (result['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  bool _isFavorite(_LocationEntry location) {
    return _favorites.any((item) =>
        item.latitude == location.latitude && item.longitude == location.longitude);
  }

  Future<void> _toggleFavorite(_LocationEntry location) async {
    setState(() {
      if (_isFavorite(location)) {
        _favorites.removeWhere((item) =>
            item.latitude == location.latitude &&
            item.longitude == location.longitude);
      } else {
        _favorites.insert(0, location);
      }
    });
    await _saveLocations();
  }

  Future<void> _selectLocation(_LocationEntry location) async {
    setState(() {
      _recent.removeWhere((item) =>
          item.latitude == location.latitude && item.longitude == location.longitude);
      _recent.insert(0, location);
      if (_recent.length > 8) _recent = _recent.take(8).toList();
    });
    await _saveLocations();
    if (!mounted) return;
    widget.onLocationSelected?.call(
      location.latitude,
      location.longitude,
      location.fullName,
    );
  }

  void _closeFavorites() {
    if (!_isFavoritesOpen) return;
    setState(() => _isFavoritesOpen = false);
    _favoritesController.reverse().whenComplete(() {
      if (mounted && !_isFavoritesOpen) {
        setState(() => _isFavoritesMounted = false);
      }
    });
  }

  void _openFavorites() {
    if (_isFavoritesOpen) return;
    setState(() {
      _isFavoritesMounted = true;
      _isFavoritesOpen = true;
    });
    _favoritesController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildBody()),
                    _buildSearchBar(),
                  ],
                ),
              ),
              if (_isFavoritesMounted) _buildFavoritesOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: SettingsConst.padHeader,
      child: Row(
        children: [
          _buildHeaderIconButton(
            tooltip: _localeManager.getText('back'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: SettingsConst.textPrimary,
              size: SettingsConst.headerIconSize,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _localeManager.getText('search'),
              style: SettingsConst.tsHeaderTitle,
            ),
          ),
          _buildHeaderIconButton(
            tooltip: _localeManager.getText('favorites_title'),
            onPressed: _openFavorites,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: -0.15, end: 0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                _isFavoritesOpen ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey(_isFavoritesOpen),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final queryActive = _searchController.text.trim().isNotEmpty;
    if (queryActive) {
      return _buildLocationList(
        _results,
        emptyText: _errorMessage ?? _localeManager.getText('search_results'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        if (_recent.isNotEmpty) ...[
          _buildSectionTitle(_localeManager.getText('recent_searches')),
          ..._recent.map(_buildLocationRow),
        ],
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required String tooltip,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.52),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLocationList(
    List<_LocationEntry> locations, {
    required String emptyText,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (locations.isEmpty) {
      return _buildEmptyState(Icons.location_off_outlined, emptyText);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: locations.map(_buildLocationRow).toList(),
    );
  }

  Widget _buildLocationRow(_LocationEntry location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _selectLocation(location),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        location.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _localeManager.getText('favorites_title'),
            onPressed: () => _toggleFavorite(location),
            icon: Icon(
              _isFavorite(location)
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: _isFavorite(location)
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _localeManager.getText('search_city'),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
          filled: true,
          fillColor: const Color(0xFF101010),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 90),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.28), size: 34),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesOverlay() {
    final panelWidth = MediaQuery.of(context).size.width * 0.75;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeFavorites,
            child: AnimatedBuilder(
              animation: _favoritesController,
              builder: (context, child) => Opacity(
                opacity: _favoritesController.value * 0.62,
                child: child,
              ),
              child: Container(color: Colors.black),
            ),
          ),
          AnimatedBuilder(
            animation: _favoritesController,
            builder: (context, child) {
              final slide = 1 - _favoritesController.value;
              return Positioned(
                top: 0,
                bottom: 0,
                right: -panelWidth * slide,
                width: panelWidth,
                child: child!,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 28,
                    offset: Offset(-8, 0),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  left: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 14, 18),
                        child: Text(
                          _localeManager.getText('favorites_title'),
                          style: SettingsConst.tsSectionTitle,
                        ),
                      ),
                      Expanded(
                        child: _favorites.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _localeManager.getText('no_favorites'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                children: _favorites.map(_buildFavoriteRow).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteRow(_LocationEntry location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _selectLocation(location),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _localeManager.getText('delete'),
            onPressed: () => _toggleFavorite(location),
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.62),
              size: 20,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ),
    );
  }
}
