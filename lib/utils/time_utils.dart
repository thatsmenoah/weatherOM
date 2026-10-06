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
}