# Weather Cloud

Погодное приложение на Flutter (Android) с двумя источниками данных, оффлайн-кешем и
обновлением без Google Play.

## Что внутри

- **Погода** — два источника: OpenWeatherMap и Open-Meteo (если первый не ответил,
  данные берутся из второго). Оффлайн-режим на основе локального кеша.
- **Экраны** — погода, «Другое» (качество воздуха и доп. метрики), поиск локаций,
  настройки с выбором языка (RU/EN) и «Что нового».
- **Firebase** — анонимная авторизация: у каждой установки свой случайный `uid`,
  без регистрации и персональных данных.
- **Обновления** — проверка новой версии через Firestore и установка APK из
  GitHub Releases прямо из приложения.

## Стек

| Слой | Технологии |
|---|---|
| UI | Flutter, Material 3 |
| Погода | OpenWeatherMap, Open-Meteo, OpenCage |
| Хранение | shared_preferences, локальный JSON-кеш |
| Бэкенд | Firebase (Auth, Firestore) |

## Структура

```
lib/
  core/        # локализация, кеш, хранилище, советы, загрузка
  screen/      # экраны приложения
  services/    # работа с API, авторизация, обновления
  widgets/     # переиспользуемые виджеты
  constants/   # цвета, отступы, типографика
  utils/       # утилиты (время, погода)
```

## Запуск

1. Установить зависимости:
   ```
   flutter pub get
   ```
2. Создать `.env` в корне (шаблон — `.env.example`):
   ```
   OPENWEATHER_API_KEY=...
   OPENCAGE_API_KEY=...
   ```
3. Запустить:
   ```
   flutter run
   ```

## Сборка релиза

```
flutter build apk --release
```

Готовый файл: `build/app/outputs/flutter-apk/app-release.apk`

Release-сборка подписывается постоянным ключом из `android/key.properties`
(файл и сам ключ `*.jks` в `.gitignore`, в репозиторий не попадают).

## Выпуск обновления

Релизы собираются автоматически через GitHub Actions. Вручную ничего собирать
не нужно.

1. Поднять версию в `pubspec.yaml` (например `version: 1.1.1-r+6`, где `6` — код
   версии; он всегда должен расти).
2. Закоммитить и запушить изменения в `main`.
3. Поставить тег и запушить его:
   ```
   git tag v1.1.1r
   git push origin v1.1.1r
   ```

Дальше GitHub Actions (`.github/workflows/release.yml`) сам:
- соберёт подписанный release-APK,
- создаст GitHub Release с этим APK,
- обновит документ `config/update` в Firestore, чтобы у пользователей появилась
  кнопка обновления.

Прогресс виден во вкладке **Actions** репозитория.

Приложение при запуске сравнивает свой код версии с `latestVersionCode` из
Firestore. Если в Firestore новее — в навигации появляется кнопка «Обновление».
Нет сети или документа — кнопки просто нет, приложение работает как обычно.

### Секреты репозитория

Workflow использует секреты (Settings → Secrets and variables → Actions):
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`,
`OPENWEATHER_API_KEY`, `OPENCAGE_API_KEY`, `FIREBASE_SERVICE_ACCOUNT`.
Они уже настроены; при смене ключа подписи или API-ключей их нужно обновить.

## Firebase

- Правила Firestore лежат в `firestore.rules` (чтение конфига — только для
  авторизованных). Деплой: `firebase deploy --only firestore:rules`.
- Конфиги Firebase (`lib/firebase_options.dart`, `android/app/google-services.json`)
  содержат только публичные идентификаторы проекта.

