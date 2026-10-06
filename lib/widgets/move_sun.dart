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
  MoveSunState createState() => MoveSunState();
}

/// Состояние публичное: экран погоды дёргает [updatePosition] через
/// GlobalKey, когда пришли новые данные. Раньше это делалось через
/// `(state as dynamic)`, и переименование метода ломало всё только в рантайме.
class MoveSunState extends State<MoveSun> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _updateTimer;
  double _progress = 0.0;
  double _targetProgress = 0.0;
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
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _progress = _controller.value * _targetProgress;
          });
        }
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
    _targetProgress = totalDuration > 0 
        ? (elapsed / totalDuration).clamp(0.0, 1.0) 
        : 0.0;
    
    if (_progress == 0) {
      _progress = _targetProgress;
    }
    
    _isNight = now.isAfter(widget.sunset) || now.isBefore(widget.sunrise);
  }

  void updatePosition() {
    _updateProgress();
    if (mounted) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _updateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pathColor;
    final Color activePathColor;
    final Color sunColor;
    final Color glowColor;
    
    if (_isNight) {
      pathColor = WeatherConst.textPrimary.withValues(alpha: 0.08);
      activePathColor = WeatherConst.textPrimary.withValues(alpha: 0.12);
      sunColor = WeatherConst.textPrimary.withValues(alpha: 0.25);
      glowColor = Colors.transparent;
    } else {
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

    final path = Path();
    path.moveTo(0, bottomY);
    path.quadraticBezierTo(centerX, topY, width, bottomY);

    final basePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

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

    if (progress > 0 && progress < 1) {
      final metrics = path.computeMetrics().first;
      final activeLength = metrics.length * progress.clamp(0.0, 1.0);
      final tangent = metrics.getTangentForOffset(activeLength);

      if (tangent != null) {
        final sunCenter = tangent.position;

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

        final sunPaint = Paint()
          ..color = sunColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(sunCenter, isNight ? 8 : 10, sunPaint);

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