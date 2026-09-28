// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/tips_system.dart';
import 'package:weather_app/utils/weather_utils.dart';
import 'package:weather_app/core/locale_manager.dart';

void main() {
  test('ночная иконка использует луну', () {
    expect(WeatherUtils.getWeatherIcon('01n'), Icons.nightlight_round);
  });

  test('советы не падают на неполному прогнозе', () {
    final weather = {
      'main': {'temp': 5, 'feels_like': 5, 'humidity': 50},
      'weather': [{'main': 'Clear'}],
    };

    final tip = TipsSystem().analyzeWeatherForTips(
      weather,
      {'list': null},
      null,
    );

    expect(tip, isNotNull);
    expect(LocaleManager().getText('no_data'), isNotEmpty);
  });
}
