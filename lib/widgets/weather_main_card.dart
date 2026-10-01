import 'package:flutter/material.dart';

import '../constants/weather_const.dart';
import '../core/loading_system.dart';
import '../core/locale_manager.dart';
import '../utils/weather_utils.dart';
import 'weather_screen_widgets.dart';

class WeatherMainCard extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  final String locationText;
  final String? subLocationText;
  final LocaleManager localeManager;
  final DateTime? updateTime;
  final bool isFromCache;

  const WeatherMainCard({
    super.key,
    required this.weatherData,
    required this.locationText,
    required this.subLocationText,
    required this.localeManager,
    required this.updateTime,
    required this.isFromCache,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final humidity = weatherData['main']['humidity'].toDouble();
    final windSpeed = weatherData['wind']['speed'].toDouble();
    final temp = weatherData['main']['temp'].round();
    final feelsLike = weatherData['main']['feels_like'].round();
    final windDeg = weatherData['wind']['deg'];
    final iconCode = weatherData['weather'][0]['icon'];
    final description = WeatherUtils.capitalize(
      WeatherUtils.getShortWeatherDescription(iconCode, localeManager),
    );

    return FadeInWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: WeatherConst.bgCard,
          borderRadius: BorderRadius.circular(WeatherConst.radiusCard),
          border: Border.all(
            color: WeatherConst.textPrimary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WeatherConst.radiusCard),
          child: Padding(
            padding: WeatherConst.padCardContent,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locationText,
                                      style: WeatherConst.tsCityName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subLocationText != null &&
                                        subLocationText!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          subLocationText!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            WeatherUtils.formatDate(now, localeManager),
                            style: WeatherConst.tsDateLabel,
                          ),
                          const SizedBox(height: 6),
                          UpdateTimeIndicator(
                            updateTime: updateTime,
                            isFromCache: isFromCache,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WeatherConst.bgCardLighter,
                        borderRadius: BorderRadius.circular(
                          WeatherConst.radiusWeatherIconBg,
                        ),
                      ),
                      child: Icon(
                        WeatherUtils.getWeatherIcon(iconCode),
                        color: WeatherConst.textPrimary,
                        size: WeatherConst.mainWeatherIconSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(child: Text('$temp°', style: WeatherConst.tsHeroTemp)),
                const SizedBox(height: 8),
                Center(
                  child: Text(description, style: WeatherConst.tsDescription),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatHumidity(humidity),
                        label: localeManager.getText('humidity'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatWindSpeed(
                          windSpeed,
                          localeManager,
                        ),
                        label:
                            '${localeManager.getText('wind')}: ${WeatherUtils.getWindDirection(windDeg, localeManager)}',
                        windDeg: windDeg?.toDouble(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatPressure(
                          weatherData['main']['pressure'].toDouble(),
                          localeManager,
                        ),
                        label: localeManager.getText('pressure'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailCard(
                        value: WeatherUtils.formatTemp(feelsLike),
                        label: localeManager.getText('feels_like'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String value,
    required String label,
    double? windDeg,
  }) {
    final isWindLabel = label.contains(localeManager.getText('wind'));

    return Container(
      padding: WeatherConst.padDetailCard,
      decoration: BoxDecoration(
        color: WeatherConst.bgDetailCard,
        borderRadius: BorderRadius.circular(WeatherConst.radiusDetailCard),
        border: Border.all(
          color: WeatherConst.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: WeatherConst.tsDetailValue.copyWith(
              color: WeatherConst.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          if (isWindLabel && windDeg != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: WeatherConst.tsDetailLabel),
                const SizedBox(width: 6),
                WeatherUtils.getWindArrow(
                  windDeg,
                  size: 16,
                  color: WeatherConst.textSecondary.withValues(alpha: 0.7),
                ),
              ],
            )
          else
            Text(label, style: WeatherConst.tsDetailLabel),
        ],
      ),
    );
  }
}