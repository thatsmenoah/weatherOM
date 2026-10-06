import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:weather_app/core/data_system.dart';

/// Подменяет path_provider на временную папку, чтобы тесты писали кеш
/// по-настоящему: иначе проверять атомарную запись и версию схемы бессмысленно.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('weather_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Map<String, dynamic> sampleCache() => {
    'weather': {
      'main': {'temp': 10.0},
      'weather': [
        {'icon': '01d', 'description': 'Ясно', 'main': 'Clear'},
      ],
    },
    'forecast': {
      'list': [
        {'dt_txt': '2026-10-05T12:00', 'main': {'temp': 10.0}},
      ],
      'daily': [
        {'dt': '2026-10-05', 'temp_max': 12.0, 'temp_min': 5.0},
      ],
    },
    'airQuality': {
      'list': [
        {
          'main': {'aqi': 2},
          'components': {'pm2_5': 5.0},
        },
      ],
    },
    'sunData': {
      'sunrise': '2026-10-05T07:12:00',
      'sunset': '2026-10-05T18:02:00',
      'timezoneOffsetSeconds': 0,
    },
    'extraMetrics': {'dewPoint': 4.5, 'uvIndex': 3.0},
    'city': 'Москва',
    'lat': 55.7558,
    'lon': 37.6173,
    'timestamp': DateTime.now().toIso8601String(),
    'locationDetails': {'city': 'Москва', 'source': 'opencage'},
    'isLocationManuallySelected': true,
  };

  void cacheFile(String name) {
    File(
      '${tempDir.path}/$name',
    ).writeAsStringSync(json.encode(sampleCache()));
  }

  group('пустой кеш', () {
    test('пустой кеш не считается валидным', () async {
      final dataSystem = DataSystem(fileName: 'empty.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isFalse);
      expect(dataSystem.getValidCache(), isNull);
      expect(dataSystem.isCacheUsable, isFalse);
      expect(dataSystem.getLatFromCache(), isNull);
      expect(dataSystem.getWeatherFromCache(), isNull);
    });

    test('пустые данные не сохраняются', () async {
      final dataSystem = DataSystem(fileName: 'empty.json');
      await dataSystem.init();
      await dataSystem.saveToCache(
        weatherData: const {},
        forecastData: null,
        airQualityData: null,
        cityName: 'Москва',
      );

      expect(File('${tempDir.path}/empty.json').existsSync(), isFalse);
      expect(dataSystem.hasData, isFalse);
    });
  });

  group('сохранение и чтение', () {
    test('данные переживают перезапуск', () async {
      final writer = DataSystem(fileName: 'weather_data.json');
      await writer.init();
      await writer.saveToCache(
        weatherData: sampleCache()['weather'] as Map<String, dynamic>,
        forecastData: sampleCache()['forecast'] as Map<String, dynamic>,
        airQualityData: sampleCache()['airQuality'] as Map<String, dynamic>,
        sunData: sampleCache()['sunData'] as Map<String, dynamic>,
        extraMetrics: sampleCache()['extraMetrics'] as Map<String, dynamic>,
        cityName: 'Москва',
        lat: 55.7558,
        lon: 37.6173,
        locationDetails: const {'city': 'Москва'},
        isLocationManuallySelected: true,
      );

      final reader = DataSystem(fileName: 'weather_data.json');
      await reader.init();

      expect(reader.hasData, isTrue);
      expect(reader.isCacheUsable, isTrue);
      expect(reader.getCityFromCache(), 'Москва');
      expect(reader.getLatFromCache(), closeTo(55.7558, 0.0001));
      expect(reader.getWeatherFromCache()?['main'], isNotNull);
      expect(reader.isLocationManuallySelectedFromCache(), isTrue);

      // Время восхода должно вернуться как DateTime, а не как строка.
      final sun = reader.getSunDataFromCache();
      expect(sun?['sunrise'], isA<DateTime>());
      expect(reader.getExtraMetricsFromCache()?['dewPoint'], 4.5);
    });

    test('временный файл не остаётся после записи', () async {
      final dataSystem = DataSystem(fileName: 'weather_data.json');
      await dataSystem.init();
      await dataSystem.saveToCache(
        weatherData: sampleCache()['weather'] as Map<String, dynamic>,
        forecastData: null,
        airQualityData: null,
        cityName: 'Москва',
      );

      expect(File('${tempDir.path}/weather_data.json.tmp').existsSync(), isFalse);
      expect(File('${tempDir.path}/weather_data.json').existsSync(), isTrue);
    });

    test('параллельные сохранения не портят файл', () async {
      final dataSystem = DataSystem(fileName: 'weather_data.json');
      await dataSystem.init();

      // Без мьютекса эти записи ложились бы в файл одновременно.
      await Future.wait([
        dataSystem.saveToCache(
          weatherData: sampleCache()['weather'] as Map<String, dynamic>,
          forecastData: null,
          airQualityData: null,
          cityName: 'Москва',
          lat: 1.0,
          lon: 2.0,
        ),
        dataSystem.saveToCache(
          weatherData: sampleCache()['weather'] as Map<String, dynamic>,
          forecastData: null,
          airQualityData: null,
          cityName: 'Абингдон',
          lat: 3.0,
          lon: 4.0,
        ),
      ]);

      // Что бы ни выиграло, файл должен остаться валидным json.
      final decoded = json.decode(
        File('${tempDir.path}/weather_data.json').readAsStringSync(),
      );
      expect(decoded, isA<Map<String, dynamic>>());

      final reader = DataSystem(fileName: 'weather_data.json');
      await reader.init();
      expect(reader.hasData, isTrue);
    });
  });

  group('устойчивость к битым данным', () {
    test('обрезанный json не роняет загрузку', () async {
      File('${tempDir.path}/broken.json').writeAsStringSync('{"weather":');

      final dataSystem = DataSystem(fileName: 'broken.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isFalse);
      expect(dataSystem.getValidCache(), isNull);
    });

    test('пустой файл игнорируется', () async {
      File('${tempDir.path}/blank.json').writeAsStringSync('   ');

      final dataSystem = DataSystem(fileName: 'blank.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isFalse);
    });

    test('кеш без версии схемы считается устаревшим', () async {
      // Так выглядит файл, записанный прошлой версией приложения.
      cacheFile('legacy.json');

      final dataSystem = DataSystem(fileName: 'legacy.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isFalse);
    });

    test('кеш с версией схемы читается', () async {
      final payload = sampleCache()..['schemaVersion'] = 2;
      File(
        '${tempDir.path}/current.json',
      ).writeAsStringSync(json.encode(payload));

      final dataSystem = DataSystem(fileName: 'current.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isTrue);
    });

    test('целые координаты в кеше не роняют экран', () async {
      // JSON без дробной части разбирается как int, а не как double.
      final payload = sampleCache()
        ..['schemaVersion'] = 2
        ..['lat'] = 55
        ..['lon'] = 37;
      File('${tempDir.path}/int_coords.json').writeAsStringSync(
        json.encode(payload),
      );

      final dataSystem = DataSystem(fileName: 'int_coords.json');
      await dataSystem.init();

      expect(dataSystem.getLatFromCache(), 55.0);
      expect(dataSystem.getLonFromCache(), 37.0);
    });
  });

  group('очистка', () {
    test('clearCache удаляет файл и сбрасывает состояние', () async {
      final dataSystem = DataSystem(fileName: 'weather_data.json');
      await dataSystem.init();
      await dataSystem.saveToCache(
        weatherData: sampleCache()['weather'] as Map<String, dynamic>,
        forecastData: null,
        airQualityData: null,
        cityName: 'Москва',
      );

      await dataSystem.clearCache();

      expect(dataSystem.hasData, isFalse);
      expect(File('${tempDir.path}/weather_data.json').existsSync(), isFalse);
    });

    test('кеш виден всем файлам из списка', () {
      // Кнопка «очистить данные» обязана знать про оба кеша, иначе один из них
      // остаётся на диске.
      expect(DataSystem.cacheFileNames, contains('weather_data.json'));
      expect(DataSystem.cacheFileNames, contains('activity_data.json'));
    });
  });

  group('свежесть кеша', () {
    test('старый кеш не считается пригодным для оффлайна', () async {
      final old = DateTime.now().subtract(const Duration(hours: 8));
      final payload = sampleCache()
        ..['schemaVersion'] = 2
        ..['timestamp'] = old.toIso8601String();
      File('${tempDir.path}/old.json').writeAsStringSync(json.encode(payload));

      final dataSystem = DataSystem(fileName: 'old.json');
      await dataSystem.init();

      expect(dataSystem.hasData, isTrue);
      expect(dataSystem.isCacheUsable, isFalse);
      // Но показать его на старте всё равно можно: главный экран сразу
      // обновляет данные с сети.
      expect(dataSystem.getValidCache(), isNotNull);
    });

    test('прогресс старения растёт со временем', () async {
      final payload = sampleCache()..['schemaVersion'] = 2;
      File(
        '${tempDir.path}/fresh.json',
      ).writeAsStringSync(json.encode(payload));

      final dataSystem = DataSystem(fileName: 'fresh.json');
      await dataSystem.init();

      final progress = dataSystem.getCacheAgingProgress();
      expect(progress, inInclusiveRange(0.0, 1.0));
      expect(progress, lessThan(0.1));
    });
  });
}
