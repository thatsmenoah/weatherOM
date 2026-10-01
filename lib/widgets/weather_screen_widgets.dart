import 'package:flutter/material.dart';

import '../constants/weather_const.dart';

class AnimatedTipCard extends StatefulWidget {
  final String title;
  final String message;
  final String timeText;
  final Color accentColor;
  final IconData icon;
  final bool isImportant;

  const AnimatedTipCard({
    super.key,
    required this.title,
    required this.message,
    required this.timeText,
    required this.accentColor,
    required this.icon,
    this.isImportant = false,
  });

  @override
  State<AnimatedTipCard> createState() => _AnimatedTipCardState();
}

class _AnimatedTipCardState extends State<AnimatedTipCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.isImportant) {
      _pulseController = AnimationController(
        duration: WeatherConst.durPulse,
        vsync: this,
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: WeatherConst.bgDetailCard,
        borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
        child: Padding(
          padding: WeatherConst.padTipCard,
          child: Row(
            children: [
              Container(
                width: WeatherConst.tipDotSize,
                height: WeatherConst.tipDotSize,
                decoration: BoxDecoration(
                  color: WeatherConst.bgForecastItem,
                  borderRadius: BorderRadius.circular(
                    WeatherConst.radiusTipIcon,
                  ),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.accentColor,
                    size: WeatherConst.tipIconSize,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: WeatherConst.tsTipTitle.copyWith(
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.message, style: WeatherConst.tsTipMessage),
                  ],
                ),
              ),
              Container(
                padding: WeatherConst.padTimeBadge,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    WeatherConst.radiusTimeBadge,
                  ),
                ),
                child: Text(
                  widget.timeText,
                  style: WeatherConst.tsTipTime.copyWith(
                    color: widget.accentColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isImportant && _pulseController != null) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulseController!,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WeatherConst.radiusTipCard),
              border: Border.all(
                color: widget.accentColor.withValues(
                  alpha: 0.2 + _pulseController!.value * 0.2,
                ),
                width: 1,
              ),
            ),
            child: card,
          ),
        ),
      );
    }

    return FadeInWrapper(
      duration: WeatherConst.durFadeIn,
      offsetY: 10,
      child: card,
    );
  }
}

class FadeInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;

  const FadeInWrapper({
    super.key,
    required this.child,
    this.duration = WeatherConst.durFadeIn,
    this.offsetY = 20.0,
  });

  @override
  State<FadeInWrapper> createState() => _FadeInWrapperState();
}

class _FadeInWrapperState extends State<FadeInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _slideAnimation, child: widget.child),
      ),
    );
  }
}