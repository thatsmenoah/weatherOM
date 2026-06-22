import 'package:flutter/material.dart';

class ChartsSheet extends StatefulWidget {
  final Map<String, dynamic> weatherData;
  final Map<String, dynamic>? forecastData;
  final VoidCallback? onClose;

  const ChartsSheet({
    super.key,
    required this.weatherData,
    this.forecastData,
    this.onClose,
  });

  @override
  State<ChartsSheet> createState() => _ChartsSheetState();
}

class _ChartsSheetState extends State<ChartsSheet> {
  List<double> _tempPoints = [];
  List<String> _timeLabels = [];
  double _minTemp = 0, _maxTemp = 0, _avgTemp = 0;
  
  List<double> _windPoints = [];
  List<double> _pressurePoints = [];
  String _pressureTrend = 'Стабильно';

  int? _selectedIndex;
  bool _isNightRange = false;

  @override
  void initState() {
    super.initState();
    _parseForecastData();
  }

  void _parseForecastData() {
    if (widget.forecastData == null || widget.forecastData!['list'] == null) {
      return;
    }

    final List<dynamic> forecastList = widget.forecastData!['list'];
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Определяем диапазон по текущему времени
    _isNightRange = currentHour < 6 || currentHour >= 18;
    
    // Фильтруем только на сегодня
    List<Map<String, dynamic>> todayForecasts = [];
    
    for (var item in forecastList) {
      final Map<String, dynamic> forecastItem = Map<String, dynamic>.from(item);
      final dtTxt = forecastItem['dt_txt'] as String? ?? '';
      
      if (dtTxt.isNotEmpty) {
        final forecastDate = DateTime.tryParse(dtTxt);
        if (forecastDate != null) {
          if (forecastDate.day == now.day && 
              forecastDate.month == now.month && 
              forecastDate.year == now.year) {
            
            final forecastHour = forecastDate.hour;
            
            if (_isNightRange) {
              // Ночной диапазон: с 12:00 до 00:00
              if (forecastHour >= 12) {
                todayForecasts.add(forecastItem);
              }
            } else {
              // Дневной диапазон: с 6 утра до 18 вечера
              if (forecastHour >= 6 && forecastHour <= 18) {
                todayForecasts.add(forecastItem);
              }
            }
          }
        }
      }
    }
    
    // Если данных мало, берём всё что есть на сегодня
    if (todayForecasts.length < 3) {
      todayForecasts = [];
      for (var item in forecastList) {
        final Map<String, dynamic> forecastItem = Map<String, dynamic>.from(item);
        final dtTxt = forecastItem['dt_txt'] as String? ?? '';
        
        if (dtTxt.isNotEmpty) {
          final forecastDate = DateTime.tryParse(dtTxt);
          if (forecastDate != null && 
              forecastDate.day == now.day && 
              forecastDate.month == now.month && 
              forecastDate.year == now.year) {
            todayForecasts.add(forecastItem);
          }
        }
      }
    }
    
    List<double> temps = [];
    List<double> winds = [];
    List<double> pressures = [];
    List<String> times = [];

    for (var item in todayForecasts) {
      // Температура
      final main = item['main'] as Map<String, dynamic>?;
      if (main != null) {
        double temp = 0.0;
        final tempValue = main['temp'];
        if (tempValue is int) {
          temp = tempValue.toDouble();
        } else if (tempValue is double) {
          temp = tempValue;
        } else if (tempValue is String) {
          temp = double.tryParse(tempValue) ?? 0.0;
        }
        temps.add(temp);
        
        // Давление
        double pressure = 745.0;
        final pressureValue = main['pressure'];
        if (pressureValue is int) {
          pressure = pressureValue.toDouble() * 0.75006;
        } else if (pressureValue is double) {
          pressure = pressureValue * 0.75006;
        } else if (pressureValue is String) {
          pressure = (double.tryParse(pressureValue) ?? 993.0) * 0.75006;
        }
        pressures.add(pressure);
      }
      
      // Ветер
      final wind = item['wind'] as Map<String, dynamic>?;
      if (wind != null) {
        double speed = 0.0;
        final speedValue = wind['speed'];
        if (speedValue is int) {
          speed = speedValue.toDouble();
        } else if (speedValue is double) {
          speed = speedValue;
        } else if (speedValue is String) {
          speed = double.tryParse(speedValue) ?? 0.0;
        }
        winds.add(speed);
      }
      
      // Время
      final dtTxt = item['dt_txt'] as String? ?? '';
      if (dtTxt.isNotEmpty) {
        final parts = dtTxt.split(' ');
        if (parts.length >= 2) {
          final timeParts = parts[1].split(':');
          times.add('${timeParts[0]}:${timeParts[1]}');
        } else {
          times.add('--:--');
        }
      } else {
        times.add('--:--');
      }
    }

    if (temps.isNotEmpty) {
      setState(() {
        _tempPoints = temps;
        _timeLabels = times;
        _windPoints = winds;
        _pressurePoints = pressures;
        
        _minTemp = temps.reduce((a, b) => a < b ? a : b);
        _maxTemp = temps.reduce((a, b) => a > b ? a : b);
        _avgTemp = temps.reduce((a, b) => a + b) / temps.length;
        
        // Тренд давления
        if (pressures.length >= 5) {
          final firstHalf = pressures.sublist(0, pressures.length ~/ 2);
          final secondHalf = pressures.sublist(pressures.length ~/ 2);
          final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
          final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
          
          if (secondAvg < firstAvg - 0.5) {
            _pressureTrend = 'Давление падает, возможны осадки';
          } else if (secondAvg > firstAvg + 0.5) {
            _pressureTrend = 'Давление растёт, погода улучшается';
          } else {
            _pressureTrend = 'Давление стабильно';
          }
        }
      });
    }
  }

  @override
Widget build(BuildContext context) {
  return Container(
    height: MediaQuery.of(context).size.height * 0.7,
    decoration: const BoxDecoration(
      color: Color(0xFF080808), // Очень темный, почти черный
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(
        top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        left: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        right: BorderSide(color: Color(0xFF2A2A2A), width: 1),
      ),
    ),
    child: Column(
      children: [
        const SizedBox(height: 12),
        // Полоска для свайпа
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Заголовок
        const Text(
          'Графики',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Скроллимый контент
        Expanded(
          child: _tempPoints.isEmpty 
            ? const Center(
                child: Text(
                  'Нет данных прогноза',
                  style: TextStyle(color: Color(0xFFa0a0a0), fontSize: 16),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildQuickSummary(),
                    const SizedBox(height: 20),
                    _buildTemperatureGraph(),
                    const SizedBox(height: 20),
                    _buildMiniCharts(),
                    const SizedBox(height: 16),
                    _buildFooter(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
        ),
      ],
    ),
  );
}

  // ========== 1. БЫСТРАЯ СВОДКА ==========
  Widget _buildQuickSummary() {
    return Row(
      children: [
        _buildSummaryCard(label: 'Мин', value: '${_minTemp.round()}°', color: const Color(0xFF60a5fa)),
        const SizedBox(width: 10),
        _buildSummaryCard(label: 'Макс', value: '${_maxTemp.round()}°', color: const Color(0xFFf87171)),
        const SizedBox(width: 10),
        _buildSummaryCard(label: 'Среднее', value: '${_avgTemp.round()}°', color: const Color(0xFFfbbf24)),
      ],
    );
  }

  Widget _buildSummaryCard({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFa0a0a0))),
          ],
        ),
      ),
    );
  }

  // ========== 2. ГРАФИК ТЕМПЕРАТУРЫ ==========
  Widget _buildTemperatureGraph() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.thermostat, color: Color(0xFFf87171), size: 18),
              SizedBox(width: 8),
              Text('Температура', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanUpdate: (details) {
                    final width = constraints.maxWidth;
                    final index = (details.localPosition.dx / width * (_tempPoints.length - 1)).round().clamp(0, _tempPoints.length - 1);
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _selectedIndex = null;
                    });
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 200),
                    painter: _TemperatureGraphPainter(
                      points: _tempPoints,
                      minTemp: _minTemp,
                      maxTemp: _maxTemp,
                      selectedIndex: _selectedIndex,
                      timeLabels: _timeLabels,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== 3. МИНИ-ГРАФИКИ (Ветер + Давление) ==========
  Widget _buildMiniCharts() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniChartCard(
            title: 'Ветер',
            icon: Icons.air,
            color: const Color(0xFF38bdf8),
            points: _windPoints,
            subtitle: _windPoints.isNotEmpty 
                ? 'Порывы до ${_windPoints.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} м/с'
                : 'Нет данных',
            isSpiky: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniChartCard(
            title: 'Давление',
            icon: Icons.speed,
            color: const Color(0xFFa78bfa),
            points: _pressurePoints,
            subtitle: _pressureTrend,
            isSpiky: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<double> points,
    required String subtitle,
    required bool isSpiky,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: points.isNotEmpty
                ? CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _MiniLinePainter(
                      points: points,
                      color: color,
                      isSpiky: isSpiky,
                    ),
                  )
                : const Center(
                    child: Text('—', style: TextStyle(color: Color(0xFFa0a0a0))),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ========== 4. ФУТЕР ==========
  Widget _buildFooter() {
    String tempTrend;
    if (_tempPoints.length >= 2) {
      final first = _tempPoints.first;
      final last = _tempPoints.last;
      if (last > first + 0.5) {
        tempTrend = 'Температура растёт';
      } else if (last < first - 0.5) {
        tempTrend = 'Температура падает';
      } else {
        tempTrend = _isNightRange ? 'Температура стабилизируется к полуночи' : 'Температура стабильна';
      }
    } else {
      tempTrend = 'Недостаточно данных';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, color: Color(0xFFa0a0a0), size: 14),
              SizedBox(width: 6),
              Text(
                'Данные на сегодня',
                style: TextStyle(fontSize: 12, color: Color(0xFFa0a0a0)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tempTrend,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ========== PAINTER ДЛЯ ГРАФИКА ТЕМПЕРАТУРЫ ==========
class _TemperatureGraphPainter extends CustomPainter {
  final List<double> points;
  final double minTemp;
  final double maxTemp;
  final int? selectedIndex;
  final List<String> timeLabels;

  _TemperatureGraphPainter({
    required this.points,
    required this.minTemp,
    required this.maxTemp,
    this.selectedIndex,
    required this.timeLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final width = size.width;
    final height = size.height - 30;
    final topPadding = 10.0;

    // Сетка
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = topPadding + height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Градиент под графиком
    if (points.length >= 2) {
      final gradientPath = Path();
      final range = (maxTemp - minTemp).clamp(0.1, double.infinity);
      
      for (int i = 0; i < points.length; i++) {
        final x = width * i / (points.length - 1);
        final y = topPadding + height * (1 - (points[i] - minTemp) / range);
        if (i == 0) {
          gradientPath.moveTo(x, topPadding + height);
          gradientPath.lineTo(x, y);
        } else {
          gradientPath.lineTo(x, y);
        }
        if (i == points.length - 1) {
          gradientPath.lineTo(x, topPadding + height);
        }
      }
      gradientPath.close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFf87171).withValues(alpha: 0.3),
            const Color(0xFFf87171).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, width, height));

      canvas.drawPath(gradientPath, gradientPaint);
    }

    // Линия графика
    final linePaint = Paint()
      ..color = const Color(0xFFf87171)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final range = (maxTemp - minTemp).clamp(0.1, double.infinity);

    for (int i = 0; i < points.length; i++) {
      final x = width * i / (points.length - 1);
      final y = topPadding + height * (1 - (points[i] - minTemp) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Точки на графике
    final dotPaint = Paint()..color = const Color(0xFFf87171);
    for (int i = 0; i < points.length; i++) {
      final x = width * i / (points.length - 1);
      final y = topPadding + height * (1 - (points[i] - minTemp) / range);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      
      // Белая обводка точек
      final dotBorderPaint = Paint()
        ..color = const Color(0xFF191919)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 3.5, dotBorderPaint);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    // Курсор при нажатии
    if (selectedIndex != null && selectedIndex! < points.length) {
      final x = width * selectedIndex! / (points.length - 1);
      final y = topPadding + height * (1 - (points[selectedIndex!] - minTemp) / range);

      // Вертикальная линия
      final cursorPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, topPadding), Offset(x, topPadding + height), cursorPaint);

      // Подсветка точки
      final highlightPaint = Paint()
        ..color = const Color(0xFFf87171)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, highlightPaint);
      
      final highlightBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 6, highlightBorderPaint);

      // Плашка со значением
      final valueText = '${points[selectedIndex!].round()}°';
      final textPainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Фон для плашки
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, topPadding - 18),
          width: textPainter.size.width + 16,
          height: 24,
        ),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        bgRect, 
        Paint()..color = const Color(0xFFf87171).withValues(alpha: 0.9),
      );
      
      textPainter.paint(canvas, Offset(x - textPainter.size.width / 2, topPadding - 30));
    }

    // Подписи времени (адаптивный шаг)
    final step = timeLabels.length > 8 ? 3 : (timeLabels.length > 5 ? 2 : 1);
    for (int i = 0; i < timeLabels.length && i < points.length; i += step) {
      final x = width * i / (points.length - 1);
      final textPainter = TextPainter(
        text: TextSpan(
          text: timeLabels[i],
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.size.width / 2, topPadding + height + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ========== PAINTER ДЛЯ МИНИ-ГРАФИКОВ ==========
class _MiniLinePainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final bool isSpiky;

  _MiniLinePainter({required this.points, required this.color, required this.isSpiky});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).clamp(0.1, double.infinity);

    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - (points[i] - minVal) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        if (isSpiky) {
          path.lineTo(x, y);
        } else {
          final prevX = size.width * (i - 1) / (points.length - 1);
          final prevY = size.height * (1 - (points[i - 1] - minVal) / range);
          path.quadraticBezierTo(prevX + (x - prevX) / 2, prevY, x, y);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}