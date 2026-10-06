import 'package:flutter/material.dart';

import '../constants/weather_const.dart';
import '../core/locale_manager.dart';
import '../utils/time_utils.dart';
import '../utils/weather_utils.dart';
import '../utils/wmo_codes.dart';
import 'weather_screen_widgets.dart';

class WeatherHourlyForecast extends StatelessWidget {
  final Map<String, dynamic>? forecastData;
  final LocaleManager localeManager;

  const WeatherHourlyForecast({
    super.key,
    required this.forecastData,
    required this.localeManager,
  });

  @override
  Widget build(BuildContext context) {
    final list = forecastData?['list'] as List?;
    if (list == null) return const SizedBox.shrink();

    final items = <Widget>[];
    for (var index = 0; index < 8 && index < list.length; index++) {
      final item = list[index];
      final time = DateTime.parse(item['dt_txt']);
      final hour = index == 0
          ? localeManager.getText('now')
          : TimeUtils.formatTimeShort(context, time);
      final temp = item['main']['temp'];
      final iconCode = item['weather'][0]['icon'];
      final description = WeatherUtils.getShortWeatherDescription(
        iconCode,
        localeManager,
      );
      final pop = item['pop'] as double?;

      items.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (index * 50)),
          offsetY: 20,
          child: _ForecastItem(
            time: hour,
            description: description,
            iconCode: iconCode,
            temperature: WeatherUtils.formatTemp(temp),
            pop: pop?.round(),
          ),
        ),
      );
    }

    return Column(children: items);
  }
}

class WeatherDailyForecast extends StatelessWidget {
  final Map<String, dynamic>? forecastData;
  final LocaleManager localeManager;

  const WeatherDailyForecast({
    super.key,
    required this.forecastData,
    required this.localeManager,
  });

  @override
  Widget build(BuildContext context) {
    if (forecastData == null) return const SizedBox.shrink();

    final dailyList = forecastData!['daily'] as List? ?? [];
    if (dailyList.isEmpty) return _buildFallback();

    final items = <Widget>[];
    for (var index = 0; index < dailyList.length && index < 7; index++) {
      final item = dailyList[index];
      final dateTime = DateTime.tryParse(item['dt'] as String);
      if (dateTime == null) continue;

      final averageTemp = (item['temp_max'] + item['temp_min']) / 2;
      final weatherCode = item['weathercode'] as int;
      final iconCode = WmoCodes.icon(weatherCode);
      final int? pop = item['precipitation_probability'] as int?;
      final label = index == 0
          ? localeManager.getText('today')
          : index == 1
          ? localeManager.getText('tomorrow')
          : WeatherUtils.getWeekday(dateTime, localeManager);
      final description = WeatherUtils.getShortWeatherDescription(
        iconCode,
        localeManager,
      );

      items.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (index * 50)),
          offsetY: 20,
          child: _ForecastItem(
            time: label,
            description: description,
            iconCode: iconCode,
            temperature: WeatherUtils.formatTemp(averageTemp),
            isDaily: true,
            pop: pop,
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildFallback() {
    final list = forecastData!['list'] as List? ?? [];
    final groupedByDay = <String, List<Map<String, dynamic>>>{};

    for (final rawItem in list) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final dateTimeText = item['dt_txt'] as String;
      final date = dateTimeText.contains('T')
          ? dateTimeText.split('T')[0]
          : dateTimeText.split(' ')[0];
      groupedByDay.putIfAbsent(date, () => []).add(item);
    }

    final items = <Widget>[];
    for (final entry in groupedByDay.entries.take(5)) {
      final dayItems = entry.value;
      var totalTemp = 0.0;
      double? maxPop;
      String iconCode = '';

      for (final item in dayItems) {
        totalTemp += (item['main']['temp'] as num).toDouble();
        final pop = (item['pop'] as num?)?.toDouble();
        if (pop != null && (maxPop == null || pop > maxPop)) maxPop = pop;
        if (iconCode.isEmpty) iconCode = item['weather'][0]['icon'];
      }

      if (dayItems.isEmpty) continue;
      final dateTime = DateTime.parse(entry.key);
      final weekday = WeatherUtils.getWeekday(dateTime, localeManager);
      final label = WeatherUtils.getDailyForecastLabel(
        items.length,
        localeManager,
      );

      items.add(
        FadeInWrapper(
          duration: Duration(milliseconds: 300 + (items.length * 50)),
          offsetY: 20,
          child: _ForecastItem(
            time: label.isNotEmpty ? label : weekday,
            description: WeatherUtils.getShortWeatherDescription(
              iconCode,
              localeManager,
            ),
            iconCode: iconCode,
            temperature: WeatherUtils.formatTemp(totalTemp / dayItems.length),
            isDaily: true,
            pop: maxPop?.round(),
          ),
        ),
      );
    }

    return Column(children: items);
  }
}

class _ForecastItem extends StatelessWidget {
  final String time;
  final String description;
  final String iconCode;
  final String temperature;
  final bool isDaily;
  final int? pop;

  const _ForecastItem({
    required this.time,
    required this.description,
    required this.iconCode,
    required this.temperature,
    this.isDaily = false,
    this.pop,
  });

  @override
  Widget build(BuildContext context) {
    const rainIcon = Icons.water_drop_outlined;
    final rainColor = Colors.grey.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: WeatherConst.padForecastItem,
      decoration: BoxDecoration(
        color: WeatherConst.bgForecastItem,
        borderRadius: BorderRadius.circular(WeatherConst.radiusForecastItem),
        border: Border.all(
          color: WeatherConst.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isDaily ? 115 : 55,
            child: Text(
              time,
              style: WeatherConst.tsForecastTime.copyWith(
                fontSize: isDaily ? 12 : 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(description, style: WeatherConst.tsForecastDesc),
          ),
          if (pop != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(rainIcon, size: 14, color: rainColor),
                  const SizedBox(width: 2),
                  Text(
                    '$pop%',
                    style: TextStyle(
                      fontSize: 12,
                      color: rainColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          Icon(
            WeatherUtils.getWeatherIcon(iconCode),
            color: WeatherConst.textPrimary,
            size: WeatherConst.forecastIconSize,
          ),
          const SizedBox(width: 12),
          Text(temperature, style: WeatherConst.tsForecastTemp),
        ],
      ),
    );
  }
}