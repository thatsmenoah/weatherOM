import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_system.dart';
import 'locale_manager.dart';

/// Информация о занимаемом месте и очистка кеша.
class StorageInfoSystem {
  static const int _gbDivider = 1024 * 1024 * 1024;
  static const int _mbDivider = 1024 * 1024;
  static const int _kbDivider = 1024;

  /// Суммарный размер хранилища приложения в байтах.
  Future<int> getCacheSize() async {
    var totalSize = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Считаем по значениям, а не по склеенной строке: раньше все ключи и
      // значения попадали в память разом, хотя нужен только их размер.
      var prefsSize = 0;
      for (final key in prefs.getKeys()) {
        prefsSize += utf8.encode(key).length;
        prefsSize += utf8.encode('${prefs.get(key)}').length;
      }
      totalSize += prefsSize;
    } catch (e) {
      debugPrint('StorageInfoSystem: не удалось измерить SharedPreferences - $e');
    }

    totalSize += await _sizeOfDirectory(await _tempDirectory());
    totalSize += await _sizeOfDirectory(await _appDirectory());
    return totalSize;
  }

  Future<Directory?> _tempDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (e) {
      debugPrint('StorageInfoSystem: нет temp-каталога - $e');
      return null;
    }
  }

  Future<Directory?> _appDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('StorageInfoSystem: нет каталога приложения - $e');
      return null;
    }
  }

  /// Рекурсивный подсчёт размера каталога.
  ///
  /// Обход асинхронный: `listSync` блокировал интерфейс на всё время сканирования,
  /// а в каталоге приложения лежат json с кешем и скачанный APK.
  Future<int> _sizeOfDirectory(Directory? directory) async {
    if (directory == null || !await directory.exists()) return 0;

    var size = 0;
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          size += await entity.length();
        } catch (e) {
          debugPrint('StorageInfoSystem: не измерить ${entity.path} - $e');
        }
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: ошибка сканирования ${directory.path} - $e');
    }
    return size;
  }

  /// Форматирует размер с локализованными единицами измерения.
  String formatSize(int bytes) {
    final localeManager = LocaleManager();
    if (bytes >= _gbDivider) {
      return '${(bytes / _gbDivider).toStringAsFixed(2)} ${localeManager.getText('size_gb')}';
    } else if (bytes >= _mbDivider) {
      return '${(bytes / _mbDivider).toStringAsFixed(2)} ${localeManager.getText('size_mb')}';
    } else if (bytes >= _kbDivider) {
      return '${(bytes / _kbDivider).toStringAsFixed(2)} ${localeManager.getText('size_kb')}';
    }
    return '$bytes ${localeManager.getText('size_b')}';
  }

  /// Удаляет содержимое временного каталога.
  Future<void> clearTempFiles() async {
    final directory = await _tempDirectory();
    if (directory == null || !await directory.exists()) return;
    await _deleteDirectoryContents(directory);
  }

  Future<void> _deleteDirectoryContents(Directory directory) async {
    try {
      await for (final entity in directory.list(
        recursive: false,
        followLinks: false,
      )) {
        try {
          await entity.delete(recursive: true);
        } catch (e) {
          debugPrint('StorageInfoSystem: не удалось удалить ${entity.path} - $e');
        }
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: ошибка очистки ${directory.path} - $e');
    }
  }

  /// Полная очистка: все файлы кеша приложения и временные файлы.
  ///
  /// Раньше чистился только тот [DataSystem], который передал экран настроек, а
  /// `activity_data.json` оставался на диске, хотя пользователь нажал «очистить
  /// всё». Теперь список файлов кеша описан в самом [DataSystem].
  Future<void> clearAllCache() async {
    for (final fileName in DataSystem.cacheFileNames) {
      try {
        await DataSystem(fileName: fileName).clearCache();
      } catch (e) {
        debugPrint('StorageInfoSystem: ошибка очистки кеша $fileName - $e');
      }
    }
    await clearTempFiles();
  }
}
