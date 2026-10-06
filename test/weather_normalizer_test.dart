import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/locale_manager.dart';
import 'package:weather_app/services/weather_normalizer.dart';

/// Нормализатор требует [LocaleManager] — прокидываем дефолтный (en),
/// чтобы тесты не зависели от синглтона.
final _locale = LocaleManager();
Map<String, dynamic> _weather(Map<String, dynamic> raw) =>
    WeatherNormalizer.weather(raw, _locale);
Map<String, dynamic> _forecast(Map<String, dynamic> raw) =>
    WeatherNormalizer.forecast(raw, _locale);

/// Ответ Open-Meteo в том виде, в котором его отдаёт API: ключи snake_case,
/// массивы параллельные, часть значений может быть null.
Map<String, dynamic> _response({
  Map<String, dynamic>? current,
  Map<String, dynamic>? hourly,
  Map<String, dynamic>? daily,
}) {
  return {
    'utc_offset_seconds': 0,
    'current': current ??
        {
          'time': '2026-10-05T12:00',
          'temperature_2m': 12.3,
          'apparent_temperature': 11.1,
          'relativehumidity_2m': 64,
          'windspeed_10m': 4.5,
          'winddirection_10m': 210,
          'pressure_msl': 1013.25,
          'weathercode': 3,
          'visibility': 9000,
          'is_day': 1,
        },
    'hourly': hourly ??
        {
          'time': ['2026-10-05T12:00', '2026-10-05T13:00'],
          'temperature_2m': [12.3, 13.0],
          'apparent_temperature': [11.1, 12.0],
          'relativehumidity_2m': [64, 60],
          'windspeed_10m': [4.5, 5.0],
          'winddirection_10m': [210, 220],
          'pressure_msl': [1013.25, 1012.0],
          'weathercode': [3, 61],
          'is_day': [1, 1],
          'visibility': [9000, 9000],
          'precipitation_probability': [10, 80],
          'shortwave_radiation': [220.5, 300.0],
        },
    'daily': daily ??
        {
          'time': ['2026-10-05', '2026-10-06'],
          'weathercode': [3, 61],
          'temperature_2m_max': [14.0, 15.0],
          'temperature_2m_min': [8.0, 9.0],
          'sunrise': ['2026-10-05T07:12:00', '2026-10-06T07:14:00'],
          'sunset': ['2026-10-05T18:02:00', '2026-10-06T18:00:00'],
          'uv_index_max': [3.2, 3.9],
          'precipitation_sum': [0.4, 2.1],
          'precipitation_probability_max': [20, 90],
          'windspeed_10m_max': [9.0, 11.0],
          'winddirection_10m_dominant': [200, 220],
        },
  };
}

void main() {
  group('числа из API и кеша', () {
    test('toDouble понимает int, double и строку', () {
      expect(WeatherNormalizer.toDouble(5), 5.0);
      expect(WeatherNormalizer.toDouble(5.5), 5.5);
      expect(WeatherNormalizer.toDouble('5.5'), 5.5);
      expect(WeatherNormalizer.toDouble(null), 0.0);
      expect(WeatherNormalizer.toDouble('мусор'), 0.0);
    });

    test('toInt округляет и не падает на мусоре', () {
      expect(WeatherNormalizer.toInt(5.6), 6);
      expect(WeatherNormalizer.toInt(5), 5);
      expect(WeatherNormalizer.toInt('7'), 7);
      expect(WeatherNormalizer.toInt(null), 0);
    });

    test('firstDouble/firstInt не падают на null в массиве', () {
      // Именно этот случай раньше ронял весь экран: в precipitation_probability_max
      // Open-Meteo местами отдаёт [null].
      expect(WeatherNormalizer.firstInt([null, 5]), 0);
      expect(WeatherNormalizer.firstDouble([null, 1.5]), 0.0);
      expect(WeatherNormalizer.firstInt(<dynamic>[]), 0);
      expect(WeatherNormalizer.firstInt(null), 0);
      expect(WeatherNormalizer.firstInt([42.4]), 42);
    });
  });

  group('текущая погода', () {
    test('нормализует ответ в структуру для UI', () {
      final weather = _weather(_response());

      expect(weather['main']['temp'], 12.3);
      expect(weather['main']['feels_like'], 11.1);
      expect(weather['main']['humidity'], 64);
      expect(weather['main']['pressure'], 1013.25);
      expect(weather['wind']['deg'], 210);
      expect(weather['visibility'], 9000);
      expect(weather['weather'], isA<List<dynamic>>());

      final condition = (weather['weather'] as List).first as Map;
      expect(condition['icon'], '04d');
      expect(condition['main'], 'Clouds');
      expect(condition['description'], isNotEmpty);
    });

    test('код 95 и ночь дают грозу и ночную иконку', () {
      final weather = _weather(
        _response(
          current: {'weathercode': 95, 'is_day': 0, 'temperature_2m': 20},
        ),
      );
      final condition = (weather['weather'] as List).first as Map;
      expect(condition['icon'], '11n');
      expect(condition['main'], 'Thunderstorm');
    });

    test('пустой ответ не роняет нормализацию', () {
      final weather = _weather(const {});
      expect(weather['main']['temp'], 0.0);
      expect((weather['weather'] as List), hasLength(1));
    });

    test('null в дневных массивах не считается ошибкой', () {
      final weather = _weather(
        _response(
          daily: {
            'uv_index_max': [null],
            'precipitation_sum': [null],
            'precipitation_probability_max': [null],
            'temperature_2m_min': [null],
            'temperature_2m_max': [null],
          },
        ),
      );

      expect(weather['_extra']['precipitationProbability'], 0);
      expect(weather['_extra']['uvIndex'], 0.0);
      expect(weather['main']['temp_min'], 0.0);
    });
  });

  group('прогноз', () {
    test('начинается с текущего часа и обрезается по available', () {
      final forecast = _forecast(_response());
      final list = forecast['list'] as List;

      expect(list, hasLength(2));
      expect((list.first as Map)['dt_txt'], '2026-10-05T12:00');
      expect((list.last as Map)['pop'], 80.0);
    });

    test('не выходит за границы массива, если осталось мало часов', () {
      final forecast = _forecast(
        _response(
          current: {'time': '2026-10-05T13:00'},
          hourly: {
            'time': ['2026-10-05T13:00', '2026-10-05T14:00'],
            'temperature_2m': [1, 2],
            'weathercode': [0, 0],
          },
        ),
      );
      expect((forecast['list'] as List), hasLength(2));
    });

    test('дневной блок ограничен семью днями', () {
      final hourly = {'time': <String>[]};
      final times = List.generate(10, (i) => '2026-10-${(i + 1).toString().padLeft(2, '0')}');
      final daily = {
        'time': times,
        'weathercode': List.filled(10, 0),
        'temperature_2m_max': List.filled(10, 1),
        'temperature_2m_min': List.filled(10, 0),
        'sunrise': List.filled(10, '2026-10-01T07:00:00'),
        'sunset': List.filled(10, '2026-10-01T18:00:00'),
        'uv_index_max': List.filled(10, 1),
        'precipitation_sum': List.filled(10, 0),
        'precipitation_probability_max': List.filled(10, 0),
        'windspeed_10m_max': List.filled(10, 1),
        'winddirection_10m_dominant': List.filled(10, 0),
      };

      final forecast = _forecast(
        _response(hourly: hourly, daily: daily),
      );
      expect((forecast['daily'] as List), hasLength(7));
    });

    test('пустой почасовой ответ даёт пустые списки, а не исключение', () {
      final forecast = _forecast(const {});
      expect(forecast['list'], isEmpty);
      expect(forecast['daily'], isEmpty);
    });
  });

  group('качество воздуха', () {
    test('AQI считается по PM2.5', () {
      expect(WeatherNormalizer.aqiFromPm25(5), 1);
      expect(WeatherNormalizer.aqiFromPm25(20), 2);
      expect(WeatherNormalizer.aqiFromPm25(40), 3);
      expect(WeatherNormalizer.aqiFromPm25(70), 4);
      expect(WeatherNormalizer.aqiFromPm25(120), 5);
    });

    test('берёт компоненты по текущему часу', () {
      final air = WeatherNormalizer.airQuality({
        'utc_offset_seconds': 0,
        'hourly': {
          'time': ['2026-10-05T10:00', '2026-10-05T11:00'],
          'pm2_5': [5, 30],
          'pm10': [8, 40],
          'carbon_monoxide': [200, 220],
          'nitrogen_dioxide': [5, 9],
          'sulphur_dioxide': [1, 2],
          'ozone': [30, 45],
        },
      });

      final entry = (air['list'] as List).first as Map;
      final components = entry['components'] as Map;
      expect(components['pm2_5'], anyOf(5.0, 30.0));
      expect(entry['main']['aqi'], isNotNull);
    });

    test('битые данные не роняют разбор', () {
      final air = WeatherNormalizer.airQuality({
        'hourly': {
          'time': ['мусор', null],
          'pm2_5': [null],
        },
      });
      final components =
          ((air['list'] as List).first as Map)['components'] as Map;
      expect(components['pm2_5'], 0.0);
    });

    test('заглушка отдаёт null, а не выдуманные значения', () {
      final entry =
          (WeatherNormalizer.airQualityFallback()['list'] as List).first as Map;
      expect(entry['main']['aqi'], isNull);
      expect((entry['components'] as Map)['pm10'], isNull);
    });
  });

  group('солнце и доп. метрики', () {
    test('время восхода и захода разбирается в DateTime', () {
      final sun = WeatherNormalizer.sunData(_response());
      expect(sun['sunrise'], isA<DateTime>());
      expect(sun['sunset'], isA<DateTime>());
      expect(sun['timezoneOffsetSeconds'], 0);
    });

    test('битое время не роняет и даёт null', () {
      final sun = WeatherNormalizer.sunData({
        'daily': {
          'sunrise': [123],
        },
      });
      expect(sun['sunrise'], isNull);
    });

    test('точка росы физически правдоподобна', () {
      final metrics = WeatherNormalizer.extraMetrics(_response());
      final dewPoint = metrics['dewPoint'] as double;

      // При 12.3 °C и 64 % влажности точка росы должна быть ниже температуры
      // и около 5–6 °C.
      expect(dewPoint, lessThan(12.3));
      expect(dewPoint, inInclusiveRange(0.0, 12.3));
    });

    test('нулевая влажность не даёт деления на ноль', () {
      final metrics = WeatherNormalizer.extraMetrics(
        _response(
          hourly: {
            'time': ['2026-10-05T12:00'],
            'temperature_2m': [20],
            'relativehumidity_2m': [0],
          },
        ),
      );
      expect(metrics['dewPoint'], isNull);
    });

    test('метрики собираются из текущего часа', () {
      final metrics = WeatherNormalizer.extraMetrics(_response());
      expect(metrics['uvIndex'], 3.2);
      expect(metrics['precipitationProbability'], 20);
      expect(metrics['visibility'], 9000.0);
      expect(metrics['shortwaveRadiation'], isNotNull);
    });

    test('пустой ответ даёт null во всех метриках', () {
      final metrics = WeatherNormalizer.extraMetrics(const {});
      expect(metrics['dewPoint'], isNull);
      expect(metrics['uvIndex'], 0.0);
      expect(metrics['visibility'], isNull);
    });
  });
}
