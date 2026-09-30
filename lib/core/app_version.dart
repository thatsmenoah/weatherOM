import 'package:package_info_plus/package_info_plus.dart';

/// Версия приложения из pubspec, доступная синхронно после [init].
///
/// Android требует, чтобы версия была валидным semver, поэтому в pubspec
/// она записана как `1.1.0-r`. Для показа убираем дефис — получается `1.1.0r`.
class AppVersion {
  AppVersion._();

  static String _display = '';

  /// Версия для показа пользователю, например `1.1.0r`.
  static String get display => _display;

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _display = info.version.replaceAll('-', '');
    } catch (_) {
      _display = '';
    }
  }
}
