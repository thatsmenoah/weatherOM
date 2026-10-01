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
import 'package:weather_app/core/data_system.dart';
import 'package:weather_app/core/locale_manager.dart';
import 'package:weather_app/services/weather_service.dart';
import 'package:weather_app/widgets/update_pill.dart';

void main() {
  test('ночная иконка использует луну', () {
    expect(WeatherUtils.getWeatherIcon('01n'), Icons.nightlight_round);
  });

  test('советы не падают на неполном прогнозе', () {
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

  test('геокодинг безопасно восстанавливается из числовых значений', () {
    final result = GeocodingResult.fromMap({
      'city': 123,
      'district': null,
      'street': 'Main street',
      'fullAddress': 'Main street, 1',
    });

    expect(result.city, '123');
    expect(result.displayName, 'Main street');
    expect(result.source, 'unknown');
  });

  test('пустой ответ погоды не считается успешными данными', () {
    final response = WeatherResponse(
      weather: const {},
      forecast: const {},
      airQuality: const {},
      sunData: const {},
      extraMetrics: const {'dewPoint': 4.5},
      errorMessage: 'network error',
    );

    expect(response.hasError, isTrue);
    expect(response.isFromOpenMeteo, isTrue);
    expect(response.toMap()['weather'], isEmpty);
    expect(response.toMap()['extraMetrics'], {'dewPoint': 4.5});
  });

  test('новый кеш без данных не считается валидным', () {
    final dataSystem = DataSystem(fileName: 'test-weather-cache.json');

    expect(dataSystem.getValidCache(), isNull);
    expect(dataSystem.getLatFromCache(), isNull);
    expect(dataSystem.getLonFromCache(), isNull);
  });

  testWidgets('кнопка обновления строится во всех состояниях', (tester) async {
    for (final state in UpdatePillState.values) {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: UpdatePill(
                  label: 'Обновление',
                  state: state,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Обновление'), findsOneWidget);

      await tester.tap(find.text('Обновление'));
      await tester.pump();

      // Во время загрузки тап по кнопке игнорируется.
      if (state == UpdatePillState.downloading) {
        expect(tapped, isFalse);
      } else {
        expect(tapped, isTrue);
      }

      // Даём анимации прокрутиться, чтобы не осталось активных тикеров.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
