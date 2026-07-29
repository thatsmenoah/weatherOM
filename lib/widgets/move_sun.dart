import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/weather_const.dart';

// ==================== АНИМИРОВАННОЕ СОЛНЦЕ ====================

class MoveSun extends StatefulWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final double width;
  final double height;

  const MoveSun({
    super.key,
    required this.sunrise,
    required this.sunset,
    this.width = double.infinity,
    this.height = 80,
  });

  @override
  State<MoveSun> createState() => _MoveSunState();
}

class _MoveSunState extends State<MoveSun> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _updateTimer;
  double _progress = 0.0;
  bool _isNight = false;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startTimer();
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _updateProgress();
  }

  void _startTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateProgress();
      if (mounted) {
        _controller.forward(from: 0);
      }
    });
  }

  void _updateProgress() {
    final now = DateTime.now();
    final totalDuration = widget.sunset.difference(widget.sunrise).inSeconds;
    final elapsed = now.difference(widget.sunrise).inSeconds;
    _progress = totalDuration > 0 
        ? (elapsed / totalDuration).clamp(0.0, 1.0) 
        : 0.0;
    
    // Проверяем, наступила ли ночь
    _isNight = now.isAfter(widget.sunset) || now.isBefore(widget.sunrise);
  }

  @override
  void dispose() {
    _controller.dispose();
    _updateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвета в зависимости от времени суток
    final Color pathColor;
    final Color activePathColor;
    final Color sunColor;
    final Color glowColor;
    
    if (_isNight) {
      // Ночные цвета - серые и тусклые
      pathColor = WeatherConst.textPrimary.withValues(alpha: 0.08);
      activePathColor = WeatherConst.textPrimary.withValues(alpha: 0.12);
      sunColor = WeatherConst.textPrimary.withValues(alpha: 0.25);
      glowColor = Colors.transparent;
    } else {
      // Дневные цвета - яркие и солнечные
      pathColor = WeatherConst.textPrimary.withValues(alpha: 0.15);
      activePathColor = WeatherConst.accentSunYellow.withValues(alpha: 0.8);
      sunColor = WeatherConst.accentSunYellow;
      glowColor = WeatherConst.accentSunYellow.withValues(alpha: 0.15);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: SunPainter(
          progress: _progress,
          isNight: _isNight,
          sunColor: sunColor,
          pathColor: pathColor,
          activePathColor: activePathColor,
          glowColor: glowColor,
        ),
      ),
    );
  }
}

// ==================== ПАИНТЕР ДЛЯ СОЛНЦА ====================

class SunPainter extends CustomPainter {
  final double progress;
  final bool isNight;
  final Color sunColor;
  final Color pathColor;
  final Color activePathColor;
  final Color glowColor;

  const SunPainter({
    required this.progress,
    this.isNight = false,
    required this.sunColor,
    required this.pathColor,
    required this.activePathColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final topY = height * 0.1;
    final bottomY = height * 0.85;

    // Строим дугу
    final path = Path();
    path.moveTo(0, bottomY);
    path.quadraticBezierTo(centerX, topY, width, bottomY);

    // Рисуем неактивную (серую) часть дуги
    final basePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

    // Рисуем активную часть дуги (пройденный путь)
    // Если ночь - рисуем серую дугу, иначе жёлтую
    if (progress > 0 && !isNight) {
      final metrics = path.computeMetrics().first;
      final activeLength = metrics.length * progress.clamp(0.0, 1.0);
      final activePath = metrics.extractPath(0, activeLength);

      final activePaint = Paint()
        ..color = activePathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(activePath, activePaint);
    }

    // Рисуем солнце/луну на дуге
    if (progress > 0 && progress < 1) {
      final metrics = path.computeMetrics().first;
      final activeLength = metrics.length * progress.clamp(0.0, 1.0);
      final tangent = metrics.getTangentForOffset(activeLength);

      if (tangent != null) {
        final sunCenter = tangent.position;

        // Свечение (только днём)
        if (!isNight) {
          final glowPaint = Paint()
            ..color = glowColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
          canvas.drawCircle(sunCenter, 30, glowPaint);

          final glowPaint2 = Paint()
            ..color = sunColor.withValues(alpha: 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
          canvas.drawCircle(sunCenter, 45, glowPaint2);
        }

        // Рисуем само солнце (или луну ночью)
        final sunPaint = Paint()
          ..color = sunColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(sunCenter, isNight ? 8 : 10, sunPaint);

        // Блик (только днём)
        if (!isNight) {
          final highlightPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(sunCenter.dx - 3, sunCenter.dy - 3), 
            3.5,
            highlightPaint,
          );
        } else {
          // Ночью рисуем полумесяц (опционально)
          // Можно добавить эффект луны
          final moonPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.1)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(sunCenter.dx + 2, sunCenter.dy - 2), 
            4,
            moonPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SunPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isNight != isNight ||
           oldDelegate.sunColor != sunColor ||
           oldDelegate.pathColor != pathColor ||
           oldDelegate.activePathColor != activePathColor ||
           oldDelegate.glowColor != glowColor;
  }
}