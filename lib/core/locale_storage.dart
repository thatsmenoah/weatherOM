import 'package:shared_preferences/shared_preferences.dart';

class LocaleStorage {
  static const String _keyLocale = 'app_locale';
  
  static Future<void> saveLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }
  
  static Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale) ?? 'Русский';
  }
}