import 'package:flutter/material.dart';
import '../utils/weather_utils.dart';

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
    final weekdays = [
      'Пн',
      'Вт',
      'Ср',
      'Чт',
      'Пт',
      'Сб',
      'Вс'
    ];
    final weekday = weekdays[now.weekday - 1];
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
          // ЛОКАЦИЯ
          Text(
            cityName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 32),
          // Основной ряд
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ГРАДУСЫ
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
              // Ощущения + день недели
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$feelsLike°',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900, // ← БЫЛО w700, СТАЛО w900
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$weekday, $time',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800, // ← БЫЛО w700, СТАЛО w800
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Иконка погоды
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