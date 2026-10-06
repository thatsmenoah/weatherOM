import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Данные о доступном обновлении, полученные из Firestore.
class UpdateInfo {
  /// Версия для показа пользователю (например "1.0.1").
  final String versionName;

  /// Числовой код версии (Android versionCode) — по нему сравниваем.
  final int versionCode;

  /// Прямая ссылка на файл APK.
  final String apkUrl;

  /// Опциональный текст "что нового".
  final String notes;

  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.notes = '',
  });
}

/// Что удалось сделать с установкой обновления.
enum InstallOutcome {
  /// Установщик Android открыт.
  opened,

  /// Система не смогла открыть файл: нет прав, нет приложения и т.п.
  failed,
}

/// Проверка и загрузка обновлений без Google Play.
///
/// Приложение спрашивает Firestore документ `config/update`:
///   latestVersionCode (int)   — обязательное, код новой версии
///   latestVersion     (string)— версия для показа (например "1.0.1")
///   apkUrl            (string)— прямая ссылка на APK
///   notes             (string)— опционально, "что нового"
///
/// Если сети нет или документа нет — просто возвращаем `null`,
/// приложение работает дальше как обычно (погода, оффлайн, кеш).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _collection = 'config';
  static const String _document = 'update';

  /// Хосты, с которых разрешено качать APK. Ссылка приходит из Firestore, то
  /// есть из внешнего источника: без проверки хоста компрометация конфига
  /// привела бы к установке чужого APK.
  static const Set<String> _allowedHosts = {'github.com', 'objects.githubusercontent.com', 'github-releases.githubusercontent.com'};

  static const Duration _downloadTimeout = Duration(minutes: 10);

  int _currentVersionCode = 0;
  String _currentVersionName = '';
  bool _isVersionKnown = false;

  int get currentVersionCode => _currentVersionCode;
  String get currentVersionName => _currentVersionName;

  /// Читает версию установленного приложения. Вызывать один раз при старте.
  ///
  /// Если прочитать не удалось, [isVersionKnown] остаётся false и проверка
  /// обновлений отключается: раньше в этом случае код версии оставался 0, и
  /// обновление предлагалось всем подряд.
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber);
      if (code == null || code <= 0) {
        debugPrint('[Update] buildNumber не распознан: ${info.buildNumber}');
        return;
      }
      _currentVersionCode = code;
      _currentVersionName = info.version;
      _isVersionKnown = true;
      debugPrint(
        '[Update] current version: $_currentVersionName ($_currentVersionCode)',
      );
    } catch (e) {
      debugPrint('[Update] init failed: $e');
    }
  }

  /// Возвращает [UpdateInfo], если доступна версия новее текущей, иначе `null`.
  ///
  /// Любая ошибка (нет сети, нет доступа, нет документа) → `null`.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!_isVersionKnown) {
      debugPrint('[Update] версия приложения неизвестна, пропускаем проверку');
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get();

      if (!doc.exists) {
        debugPrint('[Update] no update document found');
        return null;
      }

      final data = doc.data();
      if (data == null) return null;

      final latestCode = (data['latestVersionCode'] as num?)?.toInt() ?? 0;
      final apkUrl = (data['apkUrl'] as String?)?.trim() ?? '';

      if (apkUrl.isEmpty) {
        debugPrint('[Update] apkUrl is empty');
        return null;
      }

      final uri = Uri.tryParse(apkUrl);
      if (uri == null || !isTrustedApkUrl(uri)) {
        debugPrint('[Update] недоверенный apkUrl: $apkUrl');
        return null;
      }

      if (latestCode <= _currentVersionCode) {
        debugPrint('[Update] app is up to date');
        return null;
      }

      final info = UpdateInfo(
        versionName: (data['latestVersion'] as String?) ?? '$latestCode',
        versionCode: latestCode,
        apkUrl: apkUrl,
        notes: (data['notes'] as String?) ?? '',
      );

      debugPrint('[Update] update available: ${info.versionName}');
      return info;
    } catch (e) {
      debugPrint('[Update] check failed: $e');
      return null;
    }
  }

  /// Ссылка должна быть https и вести на GitHub: APK ставится в систему без
  /// дополнительной проверки, поэтому источник должен быть известным.
  @visibleForTesting
  static bool isTrustedApkUrl(Uri uri) {
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return _allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  /// Скачивает APK во временную папку приложения.
  ///
  /// Обрыв соединения раньше приводил к «успешно скачанному» обрезанному файлу,
  /// который потом отправлялся в установщик. Теперь размер ответа известен
  /// всегда: при обрыве бросаем ошибку и удаляем недокачанный файл.
  Future<File> downloadApk(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/weather-cloud-${info.versionCode}.apk');
    if (await file.exists()) {
      await file.delete();
    }

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final response = await client.send(request).timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(info.apkUrl),
        );
      }

      final total = response.contentLength ?? -1;
      sink = file.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (total > 0 && received != total) {
        throw HttpException(
          'Download incomplete: получено $received из $total байт',
          uri: Uri.parse(info.apkUrl),
        );
      }

      debugPrint('[Update] downloaded to ${file.path}');
      return file;
    } catch (_) {
      // Недокачанный файл хуже, чем никакого: установщик его не откроет, а
      // следующая попытка скачает обрыв поверх обрыва.
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      await sink?.close();
      client.close();
    }
  }

  /// Запускает системный установщик Android для скачанного APK.
  Future<InstallOutcome> installApk(File file) async {
    if (!await file.exists()) {
      debugPrint('[Update] APK не найден: ${file.path}');
      return InstallOutcome.failed;
    }
    try {
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('[Update] install result: ${result.type} ${result.message}');
      return result.type == ResultType.done
          ? InstallOutcome.opened
          : InstallOutcome.failed;
    } catch (e) {
      debugPrint('[Update] не удалось открыть установщик: $e');
      return InstallOutcome.failed;
    }
  }
}
