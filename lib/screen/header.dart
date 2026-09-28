import 'package:flutter/material.dart';
import '../utils/weather_utils.dart';
import '../utils/time_utils.dart';
import '../core/locale_manager.dart';

class CompactWeatherHeader extends StatelessWidget {
  final String cityName;
  final int temp;
  final int feelsLike;
  final String iconCode;
  final String description;
  final DateTime now;

  const CompactWeatherHeader({
    super.key,
    required this.cityName,
    required this.temp,
    required this.feelsLike,
    required this.iconCode,
    required this.description,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final localeManager = LocaleManager();
    
    final weekdays = [
      localeManager.getText('mon_short'),
      localeManager.getText('tue_short'),
      localeManager.getText('wed_short'),
      localeManager.getText('thu_short'),
      localeManager.getText('fri_short'),
      localeManager.getText('sat_short'),
      localeManager.getText('sun_short'),
    ];
    final weekday = weekdays[now.weekday - 1];
    final time = TimeUtils.formatTime(context, now);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$temp°',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$feelsLike°',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$weekday, $time',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                WeatherUtils.getWeatherIcon(iconCode),
                color: Colors.white,
                size: 80,
              ),
            ],
          ),
        ],
      ),
    );
  }
}