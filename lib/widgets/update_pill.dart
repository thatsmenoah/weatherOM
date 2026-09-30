import 'package:flutter/material.dart';

const double _pillHeight = 64;
const double _pillRadius = _pillHeight / 2;

/// Состояние кнопки обновления.
enum UpdatePillState {
  /// Обновление найдено, ещё не скачано.
  idle,

  /// Идёт загрузка APK — рамка бежит по периметру.
  downloading,

  /// APK скачан — рамка замкнулась, тап запускает установку.
  ready,
}

/// Длинная кнопка-таблетка в стиле нижней навигации.
///
/// Во время загрузки по краю бежит светящаяся рамка, после загрузки
/// рамка замыкается полностью. Справа — крестик, чтобы отложить обновление.
class UpdatePill extends StatefulWidget {
  final String label;
  final UpdatePillState state;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const UpdatePill({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<UpdatePill> createState() => _UpdatePillState();
}

class _UpdatePillState extends State<UpdatePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant UpdatePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.state == UpdatePillState.downloading) {
      _borderController.repeat();
    } else {
      _borderController.stop();
      _borderController.value = 0;
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool downloading = widget.state == UpdatePillState.downloading;
    final bool ready = widget.state == UpdatePillState.ready;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: downloading ? null : widget.onTap,
      child: SizedBox(
        height: _pillHeight,
        child: Stack(
          children: [
            // Фон в стиле круглых кнопок навигации
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_pillRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 0,
                      spreadRadius: -1,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

            // Бегущая / замкнутая рамка
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _borderController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PillBorderPainter(
                      progress: _borderController.value,
                      complete: ready,
                    ),
                  );
                },
              ),
            ),

            // Текст по центру
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // Крестик справа (отложить обновление)
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBorderPainter extends CustomPainter {
  final double progress;
  final bool complete;

  _PillBorderPainter({required this.progress, required this.complete});

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = _pillRadius;
    final rect = Rect.fromLTWH(1.2, 1.2, size.width - 2.4, size.height - 2.4);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    if (complete) {
      canvas.drawPath(path, paint);
      return;
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final total = metric.length;
    if (total == 0) return;

    // Длина бегущего сегмента ~ треть периметра.
    final segment = total * 0.34;
    final start = (progress * total) % total;
    final end = start + segment;

    if (end <= total) {
      canvas.drawPath(metric.extractPath(start, end), paint);
    } else {
      canvas.drawPath(metric.extractPath(start, total), paint);
      canvas.drawPath(metric.extractPath(0, end - total), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PillBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.complete != complete;
  }
}
