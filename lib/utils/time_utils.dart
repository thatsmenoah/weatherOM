import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Форматирование времени согласно настройкам устройства
class TimeUtils {
  /// Проверяет, используется ли на устройстве 12-часовой формат времени
  static bool is12HourFormat(BuildContext context) {
    return !MediaQuery.of(context).alwaysUse24HourFormat;
  }

  /// Форматирует время в 12-часовом формате (например, "2:30 PM")
  static String format12Hour(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Форматирует время в 24-часовом формате (например, "14:30")
  static String format24Hour(DateTime time) {
    return DateFormat.Hm().format(time);
  }

  /// Форматирует время в зависимости от системных настроек
  static String formatTime(BuildContext context, DateTime time) {
    return is12HourFormat(context) 
        ? format12Hour(time) 
        : format24Hour(time);
  }

  /// Форматирует время коротко (без AM/PM)
  static String formatTimeShort(BuildContext context, DateTime time) {
    return is12HourFormat(context)
        ? DateFormat('h:mm').format(time)
        : DateFormat.Hm().format(time);
  }

  /// Форматирует время для прогноза с поддержкой "Сейчас"
  static String formatForecastTime(BuildContext context, DateTime time, {bool isNow = false}) {
    if (isNow) return 'Сейчас';
    return formatTimeShort(context, time);
  }

  /// Форматирует время с принудительным указанием формата
  /// Если одновременно указаны force12Hour и force24Hour, приоритет у 12-часового
  static String formatTimeForced(
    DateTime time, {
    bool force12Hour = false,
    bool force24Hour = false,
  }) {
    assert(!(force12Hour && force24Hour), 'Нельзя одновременно указать force12Hour и force24Hour');
    
    if (force12Hour) return format12Hour(time);
    if (force24Hour) return format24Hour(time);
    // Если формат не указан, используем 24-часовой как fallback
    return format24Hour(time);
  }

  /// Форматирует время с принудительным указанием формата и контекстом
  static String formatTimeForcedWithContext(
    BuildContext context,
    DateTime time, {
    bool force12Hour = false,
    bool force24Hour = false,
  }) {
    assert(!(force12Hour && force24Hour), 'Нельзя одновременно указать force12Hour и force24Hour');
    
    if (force12Hour) return format12Hour(time);
    if (force24Hour) return format24Hour(time);
    return formatTime(context, time);
  }
}