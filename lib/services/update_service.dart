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

  int _currentVersionCode = 0;
  String _currentVersionName = '';

  int get currentVersionCode => _currentVersionCode;
  String get currentVersionName => _currentVersionName;

  /// Читает версию установленного приложения. Вызывать один раз при старте.
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersionCode = int.tryParse(info.buildNumber) ?? 0;
      _currentVersionName = info.version;
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

  /// Скачивает APK во временную папку приложения.
  ///
  /// [onProgress] вызывается со значением от 0.0 до 1.0 (если сервер
  /// отдаёт размер файла).
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
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(info.apkUrl),
        );
      }

      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
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

      debugPrint('[Update] downloaded to ${file.path}');
      return file;
    } finally {
      client.close();
    }
  }

  /// Запускает системный установщик Android для скачанного APK.
  Future<void> installApk(File file) async {
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    debugPrint('[Update] install result: ${result.type} ${result.message}');
  }
}
