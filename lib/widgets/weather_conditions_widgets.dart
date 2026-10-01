import 'package:flutter/material.dart';

import '../constants/weather_const.dart';
import '../core/locale_manager.dart';
import '../utils/time_utils.dart';
import '../utils/weather_utils.dart';
import 'move_sun.dart';

class WeatherSunContent extends StatelessWidget {
  final Map<String, dynamic>? sunData;
  final LocaleManager localeManager;
  final GlobalKey? moveSunKey;

  const WeatherSunContent({
    super.key,
    required this.sunData,
    required this.localeManager,
    this.moveSunKey,
  });

  @override
  Widget build(BuildContext context) {
    if (sunData == null) return const SizedBox.shrink();

    final sunrise = sunData!['sunrise'] as DateTime?;
    final sunset = sunData!['sunset'] as DateTime?;
    if (sunrise == null || sunset == null) return const SizedBox.shrink();

    final sunriseText = TimeUtils.formatTime(context, sunrise);
    final sunsetText = TimeUtils.formatTime(context, sunset);

    return Column(
      children: [
        MoveSun(
          key: moveSunKey,
          sunrise: sunrise,
          sunset: sunset,
          height: 100,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SunTime(
              label: localeManager.getText('sunrise'),
              time: sunriseText,
            ),
            const SizedBox(width: 20),
            _SunTime(
              label: localeManager.getText('sunset'),
              time: sunsetText,
            ),
          ],
        ),
      ],
    );
  }
}

class _SunTime extends StatelessWidget {
  final String label;
  final String time;

  const _SunTime({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: WeatherConst.tsSunLabel.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: WeatherConst.tsSunTime.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class WeatherAirQualityContent extends StatelessWidget {
  final Map<String, dynamic>? airQualityData;
  final LocaleManager localeManager;

  const WeatherAirQualityContent({
    super.key,
    required this.airQualityData,
    required this.localeManager,
  });

  @override
  Widget build(BuildContext context) {
    if (airQualityData == null) return const SizedBox.shrink();

    int? aqi;
    var aqiText = localeManager.getText('no_data');
    final list = airQualityData!['list'];
    if (list is List && list.isNotEmpty) {
      aqi = list[0]['main']['aqi'] as int?;
      if (aqi != null) {
        aqiText = WeatherUtils.getAirQualityText(aqi, localeManager);
      }
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    aqiText,
                    style: WeatherConst.tsAirQualityValue.copyWith(
                      color: WeatherConst.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localeManager.getText('air_quality'),
                    style: WeatherConst.tsAirQualityLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          child: Text(
            localeManager.getText('aqi'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: WeatherConst.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}