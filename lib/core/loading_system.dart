// ============================================================
//  РЎРРЎРўР•РњРђ Р—РђР“Р РЈР—РљР вЂ” С‚РѕР»СЊРєРѕ Р»РѕРіРёРєР° СЃРѕСЃС‚РѕСЏРЅРёР№.
//  UI-РІРёРґР¶РµС‚С‹ (UpdateTimeIndicator, LoadingErrorWidget,
//  StatusToast, NoGlowBehavior) РІС‹РЅРµСЃРµРЅС‹ РІ
//  widgets/loading_widgets.dart вЂ” core РЅРµ РґРѕР»Р¶РµРЅ СЃРѕРґРµСЂР¶Р°С‚СЊ РІРёРґР¶РµС‚С‹.
// ============================================================

/// РЎРѕСЃС‚РѕСЏРЅРёСЏ Р·Р°РіСЂСѓР·РєРё РґР°РЅРЅС‹С…
enum LoadingState {
  initial,
  loading,
  loaded,
  refreshing,
  error,
  offline,
}

/// РњРµРЅРµРґР¶РµСЂ СЃРѕСЃС‚РѕСЏРЅРёР№ Р·Р°РіСЂСѓР·РєРё.
///
/// РќР°РјРµСЂРµРЅРЅРѕ РЅРµ [ChangeNotifier]: РїРѕРґРїРёСЃС‡РёРєРѕРІ РЅРµС‚, СЌРєСЂР°РЅС‹ С‡РёС‚Р°СЋС‚ РіРµС‚С‚РµСЂС‹
/// РїРѕСЃР»Рµ РїРµСЂРµСЃС‚СЂРѕРµРЅРёСЏ С‡РµСЂРµР· setState. РќР°СЃР»РµРґРѕРІР°РЅРёРµ РѕС‚ ChangeNotifier С‚РѕР»СЊРєРѕ
/// СЃРѕР·РґР°РІР°Р»Рѕ Р»РёС€РЅРёРµ notifyListeners() Р±РµР· РµРґРёРЅРѕРіРѕ СЃР»СѓС€Р°С‚РµР»СЏ.
class LoadingStateManager {
  LoadingState _state = LoadingState.initial;
  String _errorMessage = '';
  bool _isUsingStorage = false;

  /// РљРѕРіРґР° РґР°РЅРЅС‹Рµ РїРѕСЃР»РµРґРЅРёР№ СЂР°Р· СѓСЃРїРµС€РЅРѕ СЃРѕС…СЂР°РЅРµРЅС‹ РІ РєРµС€
  DateTime? _cacheTimestamp;

  /// РљРѕРіРґР° РґР°РЅРЅС‹Рµ РїРѕСЃР»РµРґРЅРёР№ СЂР°Р· СѓСЃРїРµС€РЅРѕ РѕР±РЅРѕРІР»РµРЅС‹ СЃ API
  DateTime? _lastUpdateTime;

  // Р“РµС‚С‚РµСЂС‹
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isUsingStorage => _isUsingStorage;
  DateTime? get cacheTimestamp => _cacheTimestamp;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Р’СЂРµРјСЏ, РєРѕС‚РѕСЂРѕРµ РЅСѓР¶РЅРѕ РїРѕРєР°Р·Р°С‚СЊ РІ UI РїСЂСЏРјРѕ СЃРµР№С‡Р°СЃ:
  /// - РµСЃР»Рё РґР°РЅРЅС‹Рµ РёР· РєРµС€Р° вЂ” РІСЂРµРјСЏ СЃРѕС…СЂР°РЅРµРЅРёСЏ РєРµС€Р°
  /// - РµСЃР»Рё СЃРІРµР¶РёРµ вЂ” РІСЂРµРјСЏ РїРѕСЃР»РµРґРЅРµРіРѕ СѓСЃРїРµС€РЅРѕРіРѕ РѕР±РЅРѕРІР»РµРЅРёСЏ
  DateTime? get displayTime =>
      _isUsingStorage ? _cacheTimestamp : _lastUpdateTime;

  bool get isLoading => _state == LoadingState.loading;
  bool get isRefreshing => _state == LoadingState.refreshing;
  bool get hasError =>
      _state == LoadingState.error || _state == LoadingState.offline;
  bool get isOffline => _state == LoadingState.offline;

  // РњРµС‚РѕРґС‹ СѓРїСЂР°РІР»РµРЅРёСЏ СЃРѕСЃС‚РѕСЏРЅРёРµРј
  void startLoading() {
    _state = LoadingState.loading;
    _errorMessage = '';
  }

  void startRefreshing() {
    _state = LoadingState.refreshing;
    _errorMessage = '';
  }

  void finishLoading({bool fromStorage = false}) {
    _state = LoadingState.loaded;
    _isUsingStorage = fromStorage;
    // Р’СЂРµРјСЏ РїРѕСЃР»РµРґРЅРµРіРѕ РѕР±РЅРѕРІР»РµРЅРёСЏ СЃ API С‚СЂРѕРіР°РµРј С‚РѕР»СЊРєРѕ РєРѕРіРґР° РґР°РЅРЅС‹Рµ СЃРІРµР¶РёРµ.
    // Р”Р»СЏ РєРµС€Р° РёСЃРїРѕР»СЊР·СѓРµРј РѕС‚РґРµР»СЊРЅРѕРµ РїРѕР»Рµ cacheTimestamp.
    if (!fromStorage) {
      _lastUpdateTime = DateTime.now();
    }
  }

  void setCacheTimestamp(DateTime time) {
    _cacheTimestamp = time;
  }

  void setLastUpdateTime(DateTime time) {
    _lastUpdateTime = time;
  }

  void setError(String message) {
    _state = LoadingState.error;
    _errorMessage = message;
  }

  void setOfflineMode() {
    _state = LoadingState.offline;
    _isUsingStorage = true;
  }

  void reset() {
    _state = LoadingState.initial;
    _errorMessage = '';
    _isUsingStorage = false;
  }
}
