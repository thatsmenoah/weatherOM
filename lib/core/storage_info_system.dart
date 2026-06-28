import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_system.dart';  // ← было cache_system.dart

/// Система получения информации о занимаемом месте
class StorageInfoSystem {
  static const int _gbDivider = 1024 * 1024 * 1024;
  static const int _mbDivider = 1024 * 1024;
  static const int _kbDivider = 1024;

  //  ПОЛУЧЕНИЕ РАЗМЕРА КЕША 

  /// Получить размер кеша в байтах
  Future<int> getCacheSize() async {
    int totalSize = 0;

    try {
      // Размер SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsData = prefs.getKeys().map((key) {
        final value = prefs.get(key);
        return '$key$value';
      }).join();
      totalSize += utf8.encode(prefsData).length;
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка получения размера SharedPreferences: $e');
    }

    try {
      // Размер временных файлов
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        totalSize += await _getDirectorySize(tempDir);
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка получения размера временных файлов: $e');
    }

    try {
      // Размер файлов приложения
      final appDir = await getApplicationDocumentsDirectory();
      if (await appDir.exists()) {
        totalSize += await _getDirectorySize(appDir);
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка получения размера файлов приложения: $e');
    }

    return totalSize;
  }

  /// Рекурсивный подсчет размера директории
  Future<int> _getDirectorySize(Directory directory) async {
    int size = 0;

    try {
      final entities = directory.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (e) {
            debugPrint('StorageInfoSystem: Ошибка чтения размера файла ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка сканирования директории ${directory.path}: $e');
      rethrow;
    }

    return size;
  }

  //  ФОРМАТИРОВАНИЕ 

  /// Форматировать размер в читаемый вид
  String formatSize(int bytes) {
    if (bytes >= _gbDivider) {
      return '${(bytes / _gbDivider).toStringAsFixed(2)} ГБ';
    } else if (bytes >= _mbDivider) {
      return '${(bytes / _mbDivider).toStringAsFixed(2)} МБ';
    } else if (bytes >= _kbDivider) {
      return '${(bytes / _kbDivider).toStringAsFixed(2)} КБ';
    } else {
      return '$bytes Б';
    }
  }

  //  ОЧИСТКА 

  /// Очистить временные файлы
  Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await _deleteDirectoryContents(tempDir);
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка очистки временных файлов: $e');
      rethrow;
    }
  }

  /// Рекурсивное удаление содержимого директории
  Future<void> _deleteDirectoryContents(Directory directory) async {
    try {
      final entities = directory.listSync(recursive: false, followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (e) {
          debugPrint('StorageInfoSystem: Ошибка удаления ${entity.path}: $e');
          // Продолжаем удаление остальных файлов
        }
      }
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка сканирования директории для удаления ${directory.path}: $e');
      rethrow;
    }
  }

  /// Полная очистка всех данных кеша
  Future<void> clearAllCache(DataSystem dataSystem) async {  // ← было DataSystem
    try {
      await dataSystem.clearCache();
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка очистки кеша DataSystem: $e');
      rethrow;
    }

    try {
      await clearTempFiles();
    } catch (e) {
      debugPrint('StorageInfoSystem: Ошибка очистки временных файлов: $e');
      rethrow;
    }
  }
}