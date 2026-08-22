import 'locale_storage.dart';

class LocaleManager {
  static final LocaleManager _instance = LocaleManager._internal();
  factory LocaleManager() => _instance;
  LocaleManager._internal();
  
  String _currentLocale = 'Английский';
  
  // Все переводы
  static const Map<String, Map<String, String>> _translations = {
    'Русский': {
      // ============ ОБЩИЕ ============
      'app_name': 'Weather Cloud',
      'settings': 'Настройки',
      'language': 'Язык',
      'back': 'Назад',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'no_data': 'Нет данных',
      'retry': 'Повторить',
      'offline': 'Оффлайн режим',
      'cached_data': 'Используются кешированные данные',
      'refresh': 'Обновить',
      'search': 'Поиск',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'close': 'Закрыть',
      
      // ============ НАВИГАЦИЯ ============
      'main': 'Главная',
      'favorites': 'Избранное',
      'other': 'Другое',
      'graphs': 'Графики',
      
      // ============ НАСТРОЙКИ ============
      'storage': 'Хранилище',
      'storage_subtitle': 'Использование памяти устройства',
      'clear_data': 'Очистить данные',
      'about_app': 'О приложении',
      'version': 'Версия',
      'changelog': 'Что нового?',
      'copyright': '© 2026 Weather Cloud',
      
      // ============ ПОГОДА ============
      'weather': 'Погода',
      'humidity': 'Влажность',
      'wind': 'Ветер',
      'pressure': 'Давление',
      'feels_like': 'Ощущается',
      'sunrise': 'Рассвет',
      'sunset': 'Закат',
      'air_quality': 'Качество воздуха',
      'aqi': 'AQI',
      'now': 'Сейчас',
      'today': 'Сегодня',
      'tomorrow': 'Завтра',
      'hourly': 'Почасовой прогноз',
      'daily': 'Прогноз на 5 дней',
      'precipitation': 'Осадки',
      'precipitation_prob': 'Вероятность осадков',
      'dew_point': 'Точка росы',
      'visibility': 'Видимость',
      'uv_index': 'УФ-индекс',
      'solar_radiation': 'Солнечная радиация',
      'wind_direction': 'Направление ветра',
      'update_time': 'Обновлено',
      'just_now': 'Только что',
      'minutes_ago': 'мин. назад',
      'hours_ago': 'ч. назад',
      'days_ago': 'д. назад',
      'never': 'Никогда',
      
      // ============ КАЧЕСТВО ВОЗДУХА ============
      'air_excellent': 'Отличное',
      'air_good': 'Хорошее',
      'air_moderate': 'Умеренное',
      'air_poor': 'Плохое',
      'air_very_poor': 'Очень плохое',
      'pm25': 'PM2.5',
      'pm10': 'PM10',
      'co': 'CO',
      'no2': 'NO₂',
      'o3': 'O₃',
      'so2': 'SO₂',
      'pm25_desc': 'Мелкие частицы',
      'pm10_desc': 'Крупные частицы',
      'co_desc': 'Угарный газ',
      'no2_desc': 'Диоксид азота',
      'o3_desc': 'Озон',
      'so2_desc': 'Диоксид серы',
      
      // ============ ДНИ НЕДЕЛИ ============
      'monday': 'Понедельник',
      'tuesday': 'Вторник',
      'wednesday': 'Среда',
      'thursday': 'Четверг',
      'friday': 'Пятница',
      'saturday': 'Суббота',
      'sunday': 'Воскресенье',
      'mon_short': 'Пн',
      'tue_short': 'Вт',
      'wed_short': 'Ср',
      'thu_short': 'Чт',
      'fri_short': 'Пт',
      'sat_short': 'Сб',
      'sun_short': 'Вс',
      
      // ============ МЕСЯЦЫ ============
      'january': 'января',
      'february': 'февраля',
      'march': 'марта',
      'april': 'апреля',
      'may': 'мая',
      'june': 'июня',
      'july': 'июля',
      'august': 'августа',
      'september': 'сентября',
      'october': 'октября',
      'november': 'ноября',
      'december': 'декабря',
      
      // ============ НАПРАВЛЕНИЯ ВЕТРА ============
      'n': 'Север',
      'ne': 'С-В',
      'e': 'Восток',
      'se': 'Ю-В',
      's': 'Юг',
      'sw': 'Ю-З',
      'w': 'Запад',
      'nw': 'С-З',
      'ms': 'm/s',
      'mm': 'мм',
      
      // ============ ОПИСАНИЯ ПОГОДЫ ============
      'clear_sky': 'Ясное небо',
      'mostly_clear': 'Преимущественно ясно',
      'partly_cloudy': 'Переменная облачность',
      'overcast': 'Пасмурно',
      'fog': 'Туман',
      'freezing_fog': 'Туман с изморозью',
      'light_drizzle': 'Легкая морось',
      'moderate_drizzle': 'Умеренная морось',
      'heavy_drizzle': 'Сильная морось',
      'light_freezing_drizzle': 'Легкая ледяная морось',
      'heavy_freezing_drizzle': 'Сильная ледяная морось',
      'light_rain': 'Легкий дождь',
      'moderate_rain': 'Умеренный дождь',
      'heavy_rain': 'Сильный дождь',
      'light_freezing_rain': 'Легкий ледяной дождь',
      'heavy_freezing_rain': 'Сильный ледяной дождь',
      'light_snow': 'Легкий снегопад',
      'moderate_snow': 'Умеренный снегопад',
      'heavy_snow': 'Сильный снегопад',
      'snow_grains': 'Снежная крупа',
      'light_shower': 'Легкий ливень',
      'moderate_shower': 'Умеренный ливень',
      'heavy_shower': 'Сильный ливень',
      'light_snow_shower': 'Легкий снегопад',
      'heavy_snow_shower': 'Сильный снегопад',
      'thunderstorm': 'Гроза',
      'thunderstorm_hail': 'Гроза с градом',
      'heavy_thunderstorm': 'Сильная гроза с градом',
      'unknown': 'Неизвестно',
      
      // ============ КОРОТКИЕ ОПИСАНИЯ ============
      'desc_clear': 'Ясно',
      'desc_cloudy': 'Облачно',
      'desc_overcast': 'Пасмурно',
      'desc_rain': 'Дождь',
      'desc_thunderstorm': 'Гроза',
      'desc_snow': 'Снег',
      'desc_fog': 'Туман',
      
      // ============ СОВЕТЫ ============
      'tip_sunrise_title': 'Рассвет',
      'tip_sunrise_msg1': 'Скоро рассвет.',
      'tip_sunrise_msg2': 'Начинается новый день.',
      'tip_sunrise_msg3': 'Хорошего утра :)',
      
      'tip_sunset_title': 'Закат',
      'tip_sunset_msg1': 'Скоро закат.',
      'tip_sunset_msg2': 'День подходит к завершению.',
      
      'tip_snow_title': 'Снегопад',
      'tip_snow_msg1': 'Ожидается снег в ближайшее время.',
      'tip_snow_msg2': 'На улице снег - одевайтесь теплее.',
      'tip_snow_msg3': 'Возможна скользкая дорога, будьте аккуратны.',
      
      'tip_rain_title': 'Возможен дождь',
      'tip_rain_light': 'небольшой',
      'tip_rain_moderate': 'умеренный',
      'tip_rain_heavy': 'сильный',
      'tip_rain_msg1': 'Ожидается дождь - возьмите зонт.',
      'tip_rain_msg2': 'Возможны осадки, лучше одеться соответствующе.',
      'tip_rain_msg3': 'На улице может идти дождь, учитывайте это при выходе.',
      
      'tip_night_title': 'Ночь',
      'tip_night_msg1': 'Сейчас ночь, лучше отдохнуть.',
      'tip_night_msg2': 'На улице {temp}°C - проветрите перед сном.',
      'tip_night_msg3': 'Температура {temp}°C, комфортно для сна.',
      
      'tip_morning_cold_title': 'Холодное утро',
      'tip_morning_cold_msg': 'На улице {temp}°C, одевайтесь теплее.',
      
      'tip_morning_humid_title': 'Влажное утро',
      'tip_morning_humid_msg': 'Температура {temp}°C, влажность высокая - возможна духота.',
      
      'tip_morning_title': 'Утро',
      'tip_morning_msg1': 'Утро комфортное, можно проветрить помещение.',
      'tip_morning_msg2': 'На улице {temp}°C - нормальная погода для начала дня.',
      'tip_morning_msg3': 'Свежий воздух, хорошее утро.',
      
      'tip_clear_title': 'Ясно',
      'tip_clear_msg1': 'Ясная погода, хорошее время для прогулки.',
      'tip_clear_msg2': 'Солнечно, можно выйти на улицу.',
      'tip_clear_msg3': 'Комфортная погода для активности.',
      
      'tip_clouds_title': 'Облачно',
      'tip_clouds_msg1': 'Облачно, без осадков.',
      'tip_clouds_msg2': 'Облачно, возможно пасмурно, но стабильно.',
      'tip_clouds_msg3': 'Обычная погода для дел вне дома.',
      
      'tip_rainy_title': 'Дождь',
      'tip_rainy_msg1': 'Идёт дождь, лучше взять зонт.',
      'tip_rainy_msg2': 'Осадки на улице, учитите это.',
      'tip_rainy_msg3': 'Мокрая погода, будьте осторожны.',
      
      'tip_snowy_title': 'Снег',
      'tip_snowy_msg1': 'Снег на улице, одевайтесь теплее.',
      'tip_snowy_msg2': 'Зимняя погода, возможен гололёд.',
      'tip_snowy_msg3': 'Холодно и снежно.',
      
      'tip_thunder_title': 'Гроза',
      'tip_thunder_msg1': 'Гроза, лучше оставаться в помещении.',
      'tip_thunder_msg2': 'Штормовая погода, соблюдайте осторожность.',
      'tip_thunder_msg3': 'Возможны разряды молний.',
      
      'tip_drizzle_title': 'Морось',
      'tip_drizzle_msg1': 'Морось, возможна влажность.',
      'tip_drizzle_msg2': 'Лёгкие осадки.',
      'tip_drizzle_msg3': 'Слабый дождь.',
      
      'tip_fog_title': 'Туман',
      'tip_fog_msg1': 'Туман, ограниченная видимость.',
      'tip_fog_msg2': 'Будьте осторожны на дороге.',
      'tip_fog_msg3': 'Плохая видимость.',
      
      'tip_default_title': 'Совет',
      'tip_default_msg1': 'Обычная погода.',
      'tip_default_msg2': 'Одевайтесь по погоде.',
      'tip_default_msg3': 'Следите за изменениями прогноза.',
      
      // ============ ДОПОЛНИТЕЛЬНЫЕ МЕТРИКИ ============
      'uv_low': 'Низкий',
      'uv_moderate': 'Умеренный',
      'uv_high': 'Высокий',
      'uv_very_high': 'Очень высокий',
      'uv_extreme': 'Экстремальный',
      
      'dew_comfort': 'Комфортно',
      'dew_humid': 'Влажно',
      'dew_stuffy': 'Душно',
      'dew_dry': 'Сухо',
      
      'visibility_excellent': 'Отличная',
      'visibility_good': 'Хорошая',
      'visibility_moderate': 'Средняя',
      'visibility_fog': 'Туман',
      
      'precip_none': 'Без осадков',
      'precip_unlikely': 'Маловероятно',
      'precip_possible': 'Возможно',
      'precip_likely': 'Вероятно',
      'precip_certain': 'Точно будет',
      
      'radiation_night': 'Ночь',
      'radiation_overcast': 'Пасмурно',
      'radiation_cloudy': 'Облачно',
      'radiation_partly': 'Переменная облачность',
      'radiation_clear': 'Ясно',
      
      // ============ FAVORITES ============
      'favorites_title': 'Избранное',
      'current_location': 'Текущее местоположение',
      'recent_searches': 'Недавно искали',
      'favorite_locations': 'Избранные локации',
      'search_city': 'Поиск города...',
      'no_favorites': 'Нет избранных локаций',
      'no_favorites_hint': 'Используйте поиск, чтобы добавить город',
      'city_not_found': 'Город не найден',
      'search_results': 'Результаты поиска',
      'priority': 'Приоритет',
      'now_label': 'Сейчас',
      
      // ============ ACTIVITY ============
      'air_quality_title': 'Качество воздуха',
      'overall_index': 'Общий индекс',
      'additional_metrics': 'Дополнительно',
      'no_internet': 'Проверьте подключение к интернету',
      'refresh_error': 'Ошибка обновления',
      'offline_mode': 'Оффлайн режим • Используются кешированные данные',
      'update_failed': 'Не удалось обновить данные',
      
      // ============ POLLUTANTS ============
      'pm25_full': 'Мелкие частицы',
      'pm10_full': 'Крупные частицы',
      'co_full': 'Угарный газ',
      'no2_full': 'Диоксид азота',
      'o3_full': 'Озон',
      'so2_full': 'Диоксид серы',
    },
    
    'Английский': {
      // ============ ОБЩИЕ ============
      'app_name': 'Weather Cloud',
      'settings': 'Settings',
      'language': 'Language',
      'back': 'Back',
      'loading': 'Loading...',
      'error': 'Error',
      'no_data': 'No data',
      'retry': 'Retry',
      'offline': 'Offline mode',
      'cached_data': 'Using cached data',
      'refresh': 'Refresh',
      'search': 'Search',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'close': 'Close',
      
      // ============ НАВИГАЦИЯ ============
      'main': 'Main',
      'favorites': 'Favorites',
      'other': 'Other',
      'graphs': 'Graphs',
      
      // ============ НАСТРОЙКИ ============
      'storage': 'Storage',
      'storage_subtitle': 'Device memory usage',
      'clear_data': 'Clear data',
      'about_app': 'About',
      'version': 'Version',
      'changelog': 'What\'s new?',
      'copyright': '© 2026 Weather Cloud',
      
      // ============ ПОГОДА ============
      'weather': 'Weather',
      'humidity': 'Humidity',
      'wind': 'Wind',
      'pressure': 'Pressure',
      'feels_like': 'Feels like',
      'sunrise': 'Sunrise',
      'sunset': 'Sunset',
      'air_quality': 'Air quality',
      'aqi': 'AQI',
      'now': 'Now',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'hourly': 'Hourly forecast',
      'daily': '5-day forecast',
      'precipitation': 'Precipitation',
      'precipitation_prob': 'Precipitation probability',
      'dew_point': 'Dew point',
      'visibility': 'Visibility',
      'uv_index': 'UV index',
      'solar_radiation': 'Solar radiation',
      'wind_direction': 'Wind direction',
      'update_time': 'Updated',
      'just_now': 'Just now',
      'minutes_ago': 'min ago',
      'hours_ago': 'h ago',
      'days_ago': 'd ago',
      'never': 'Never',
      
      // ============ КАЧЕСТВО ВОЗДУХА ============
      'air_excellent': 'Excellent',
      'air_good': 'Good',
      'air_moderate': 'Moderate',
      'air_poor': 'Poor',
      'air_very_poor': 'Very poor',
      'pm25': 'PM2.5',
      'pm10': 'PM10',
      'co': 'CO',
      'no2': 'NO₂',
      'o3': 'O₃',
      'so2': 'SO₂',
      'pm25_desc': 'Fine particles',
      'pm10_desc': 'Coarse particles',
      'co_desc': 'Carbon monoxide',
      'no2_desc': 'Nitrogen dioxide',
      'o3_desc': 'Ozone',
      'so2_desc': 'Sulfur dioxide',
      
      // ============ ДНИ НЕДЕЛИ ============
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'mon_short': 'Mon',
      'tue_short': 'Tue',
      'wed_short': 'Wed',
      'thu_short': 'Thu',
      'fri_short': 'Fri',
      'sat_short': 'Sat',
      'sun_short': 'Sun',
      
      // ============ МЕСЯЦЫ ============
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',
      
      // ============ НАПРАВЛЕНИЯ ВЕТРА ============
      'n': 'North',
      'ne': 'N-E',
      'e': 'East', 
      'se': 'S-E',
      's': 'South',
      'sw': 'S-W',
      'w': 'West',
      'nw': 'N-W',
      'ms': 'm/s',
      'mm': 'mm',
      
      // ============ ОПИСАНИЯ ПОГОДЫ ============
      'clear_sky': 'Clear sky',
      'mostly_clear': 'Mostly clear',
      'partly_cloudy': 'Partly cloudy',
      'overcast': 'Overcast',
      'fog': 'Fog',
      'freezing_fog': 'Freezing fog',
      'light_drizzle': 'Light drizzle',
      'moderate_drizzle': 'Moderate drizzle',
      'heavy_drizzle': 'Heavy drizzle',
      'light_freezing_drizzle': 'Light freezing drizzle',
      'heavy_freezing_drizzle': 'Heavy freezing drizzle',
      'light_rain': 'Light rain',
      'moderate_rain': 'Moderate rain',
      'heavy_rain': 'Heavy rain',
      'light_freezing_rain': 'Light freezing rain',
      'heavy_freezing_rain': 'Heavy freezing rain',
      'light_snow': 'Light snowfall',
      'moderate_snow': 'Moderate snowfall',
      'heavy_snow': 'Heavy snowfall',
      'snow_grains': 'Snow grains',
      'light_shower': 'Light shower',
      'moderate_shower': 'Moderate shower',
      'heavy_shower': 'Heavy shower',
      'light_snow_shower': 'Light snow shower',
      'heavy_snow_shower': 'Heavy snow shower',
      'thunderstorm': 'Thunderstorm',
      'thunderstorm_hail': 'Thunderstorm with hail',
      'heavy_thunderstorm': 'Heavy thunderstorm with hail',
      'unknown': 'Unknown',
      
      // ============ КОРОТКИЕ ОПИСАНИЯ ============
      'desc_clear': 'Clear',
      'desc_cloudy': 'Cloudy',
      'desc_overcast': 'Overcast',
      'desc_rain': 'Rain',
      'desc_thunderstorm': 'Thunderstorm',
      'desc_snow': 'Snow',
      'desc_fog': 'Fog',
      
      // ============ СОВЕТЫ ============
      'tip_sunrise_title': 'Sunrise',
      'tip_sunrise_msg1': 'Sunrise is coming soon.',
      'tip_sunrise_msg2': 'A new day begins.',
      'tip_sunrise_msg3': 'Good morning :)',
      
      'tip_sunset_title': 'Sunset',
      'tip_sunset_msg1': 'Sunset is coming soon.',
      'tip_sunset_msg2': 'The day is coming to an end.',
      
      'tip_snow_title': 'Snowfall',
      'tip_snow_msg1': 'Snow is expected soon.',
      'tip_snow_msg2': 'It\'s snowing outside - dress warmly.',
      'tip_snow_msg3': 'Slippery roads possible, be careful.',
      
      'tip_rain_title': 'Possible rain',
      'tip_rain_light': 'light',
      'tip_rain_moderate': 'moderate',
      'tip_rain_heavy': 'heavy',
      'tip_rain_msg1': 'Rain expected - take an umbrella.',
      'tip_rain_msg2': 'Precipitation possible, dress accordingly.',
      'tip_rain_msg3': 'It may rain outside, keep that in mind when going out.',
      
      'tip_night_title': 'Night',
      'tip_night_msg1': 'It\'s night, better get some rest.',
      'tip_night_msg2': 'It\'s {temp}°C outside - air out before bed.',
      'tip_night_msg3': 'Temperature {temp}°C, comfortable for sleeping.',
      
      'tip_morning_cold_title': 'Cold morning',
      'tip_morning_cold_msg': 'It\'s {temp}°C outside - dress warmly.',
      
      'tip_morning_humid_title': 'Humid morning',
      'tip_morning_humid_msg': 'Temperature {temp}°C, high humidity - might feel stuffy.',
      
      'tip_morning_title': 'Morning',
      'tip_morning_msg1': 'Comfortable morning, you can air out the room.',
      'tip_morning_msg2': 'It\'s {temp}°C outside - normal weather to start the day.',
      'tip_morning_msg3': 'Fresh air, good morning.',
      
      'tip_clear_title': 'Clear',
      'tip_clear_msg1': 'Clear weather, good time for a walk.',
      'tip_clear_msg2': 'Sunny, you can go outside.',
      'tip_clear_msg3': 'Comfortable weather for activities.',
      
      'tip_clouds_title': 'Cloudy',
      'tip_clouds_msg1': 'Cloudy, no precipitation.',
      'tip_clouds_msg2': 'Cloudy, possibly overcast but stable.',
      'tip_clouds_msg3': 'Normal weather for errands.',
      
      'tip_rainy_title': 'Rain',
      'tip_rainy_msg1': 'It\'s raining, better take an umbrella.',
      'tip_rainy_msg2': 'Precipitation outside, keep that in mind.',
      'tip_rainy_msg3': 'Wet weather, be careful.',
      
      'tip_snowy_title': 'Snow',
      'tip_snowy_msg1': 'Snow outside, dress warmly.',
      'tip_snowy_msg2': 'Winter weather, possible ice.',
      'tip_snowy_msg3': 'Cold and snowy.',
      
      'tip_thunder_title': 'Thunderstorm',
      'tip_thunder_msg1': 'Thunderstorm, better stay indoors.',
      'tip_thunder_msg2': 'Stormy weather, be cautious.',
      'tip_thunder_msg3': 'Lightning strikes possible.',
      
      'tip_drizzle_title': 'Drizzle',
      'tip_drizzle_msg1': 'Drizzle, possible humidity.',
      'tip_drizzle_msg2': 'Light precipitation.',
      'tip_drizzle_msg3': 'Light rain.',
      
      'tip_fog_title': 'Fog',
      'tip_fog_msg1': 'Fog, limited visibility.',
      'tip_fog_msg2': 'Be careful on the road.',
      'tip_fog_msg3': 'Poor visibility.',
      
      'tip_default_title': 'Tip',
      'tip_default_msg1': 'Normal weather.',
      'tip_default_msg2': 'Dress for the weather.',
      'tip_default_msg3': 'Keep an eye on the forecast changes.',
      
      // ============ ДОПОЛНИТЕЛЬНЫЕ МЕТРИКИ ============
      'uv_low': 'Low',
      'uv_moderate': 'Moderate',
      'uv_high': 'High',
      'uv_very_high': 'Very high',
      'uv_extreme': 'Extreme',
      
      'dew_comfort': 'Comfortable',
      'dew_humid': 'Humid',
      'dew_stuffy': 'Stuffy',
      'dew_dry': 'Dry',
      
      'visibility_excellent': 'Excellent',
      'visibility_good': 'Good',
      'visibility_moderate': 'Moderate',
      'visibility_fog': 'Fog',
      
      'precip_none': 'No precipitation',
      'precip_unlikely': 'Unlikely',
      'precip_possible': 'Possible',
      'precip_likely': 'Likely',
      'precip_certain': 'Certain',
      
      'radiation_night': 'Night',
      'radiation_overcast': 'Overcast',
      'radiation_cloudy': 'Cloudy',
      'radiation_partly': 'Partly cloudy',
      'radiation_clear': 'Clear',
      
      // ============ FAVORITES ============
      'favorites_title': 'Favorites',
      'current_location': 'Current location',
      'recent_searches': 'Recent searches',
      'favorite_locations': 'Favorite locations',
      'search_city': 'Search city...',
      'no_favorites': 'No favorite locations',
      'no_favorites_hint': 'Use search to add a city',
      'city_not_found': 'City not found',
      'search_results': 'Search results',
      'priority': 'Priority',
      'now_label': 'Now',
      
      // ============ ACTIVITY ============
      'air_quality_title': 'Air quality',
      'overall_index': 'Overall index',
      'additional_metrics': 'Additional metrics',
      'no_internet': 'Check your internet connection',
      'refresh_error': 'Refresh error',
      'offline_mode': 'Offline mode • Using cached data',
      'update_failed': 'Failed to update data',
      
      // ============ POLLUTANTS ============
      'pm25_full': 'Fine particles',
      'pm10_full': 'Coarse particles',
      'co_full': 'Carbon monoxide',
      'no2_full': 'Nitrogen dioxide',
      'o3_full': 'Ozone',
      'so2_full': 'Sulfur dioxide',
    },
  };
  
  // Инициализация - загружаем сохранённый язык
  Future<void> init() async {
    _currentLocale = await LocaleStorage.getLocale();
  }
  
  // Получить текущий язык
  String get currentLocale => _currentLocale;
  
  // Сменить язык
  Future<void> setLocale(String newLocale) async {
    if (_translations.containsKey(newLocale)) {
      _currentLocale = newLocale;
      await LocaleStorage.saveLocale(newLocale);
    }
  }
  
  // Получить перевод по ключу
  String getText(String key) {
    return _translations[_currentLocale]?[key] ?? key;
  }
  
  // Получить перевод с подстановкой
  String getTextWithArgs(String key, Map<String, String> args) {
    String text = getText(key);
    for (final entry in args.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }
  
  // Получить все доступные языки
  List<String> get availableLocales => _translations.keys.toList();
}