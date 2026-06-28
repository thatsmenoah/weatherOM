import 'package:flutter/material.dart';

//  СИСТЕМА ЗАГРУЗКИ 

/// Состояния загрузки данных
enum LoadingState {
  initial,        // Начальное состояние
  loading,        // Загрузка (поверх данных из хранилища)
  loaded,         // Загружено
  refreshing,     // Обновление
  error,          // Ошибка (нет интернета, сервер недоступен)
  offline,        // Оффлайн режим (работаем с кешем)
  usingFallback,  // Используется резервный источник (OM) - НЕ ОШИБКА!
}

/// Менеджер состояний загрузки
class LoadingStateManager extends ChangeNotifier {
  LoadingState _state = LoadingState.initial;
  String _errorMessage = '';
  bool _isUsingStorage = false;
  DateTime? _lastUpdateTime;
  
  LoadingState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isUsingStorage => _isUsingStorage;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  
  bool get isLoading => _state == LoadingState.loading;
  bool get isRefreshing => _state == LoadingState.refreshing;
  bool get hasError => _state == LoadingState.error || _state == LoadingState.offline;
  bool get isOffline => _state == LoadingState.offline;
  bool get isUsingFallback => _state == LoadingState.usingFallback; // НОВОЕ
  
  void startLoading() {
    _state = LoadingState.loading;
    _errorMessage = '';
    notifyListeners();
  }
  
  void startRefreshing() {
    _state = LoadingState.refreshing;
    _errorMessage = '';
    notifyListeners();
  }
  
  void finishLoading({bool fromStorage = false}) {
    _state = LoadingState.loaded;
    _isUsingStorage = fromStorage;
    _lastUpdateTime = DateTime.now();
    notifyListeners();
  }
  
  // НОВЫЙ МЕТОД - когда используем Open-Meteo (это не ошибка!)
  void setFallbackMode() {
    _state = LoadingState.usingFallback;
    _isUsingStorage = false; // Данные свежие, просто из другого источника
    _errorMessage = '';
    _lastUpdateTime = DateTime.now();
    notifyListeners();
  }
  
  void setError(String message) {
    _state = LoadingState.error;
    _errorMessage = message;
    notifyListeners();
  }
  
  void setOfflineMode() {
    _state = LoadingState.offline;
    _isUsingStorage = true;
    notifyListeners();
  }
  
  void setLastUpdateTime(DateTime time) {
    _lastUpdateTime = time;
    notifyListeners();
  }
  
  void reset() {
    _state = LoadingState.initial;
    _errorMessage = '';
    _isUsingStorage = false;
    notifyListeners();
  }
}

//  ВИДЖЕТЫ ЗАГРУЗКИ 

/// Индикатор времени последнего обновления
class UpdateTimeIndicator extends StatelessWidget {
  final DateTime? updateTime;
  final bool isFromCache;
  
  const UpdateTimeIndicator({
    super.key,
    required this.updateTime,
    required this.isFromCache,
  });
  
  String _getCacheStatus() {
    final messages = ['Не обновлено', 'Устаревшие данные', 'Кеш данные'];
    final randomIndex = DateTime.now().millisecond % messages.length;
    return messages[randomIndex];
  }
  
  String _formatTime() {
    if (updateTime == null) return 'Обновлено: никогда';
    
    final hour = updateTime!.hour.toString().padLeft(2, '0');
    final minute = updateTime!.minute.toString().padLeft(2, '0');
    return 'Обновлено в $hour:$minute';
  }
  
  @override
  Widget build(BuildContext context) {
    final String displayText;
    final IconData displayIcon;
    
    if (isFromCache) {
      displayText = _getCacheStatus();
      displayIcon = Icons.storage;
    } else {
      displayText = _formatTime();
      displayIcon = Icons.update;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            displayIcon,
            size: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кружок загрузки (поверх контента)
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}

/// Экран ошибки загрузки
class LoadingErrorWidget extends StatelessWidget {
  final String message;
  final String? subtitle;
  final VoidCallback onRetry;
  final bool isOffline;
  
  const LoadingErrorWidget({
    super.key,
    required this.message,
    this.subtitle,
    required this.onRetry,
    this.isOffline = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline, 
              color: const Color(0xFFdc2626), 
              size: 64
            ),
            const SizedBox(height: 16),
            Text(
              message, 
              style: const TextStyle(
                color: Color(0xFFdc2626), 
                fontSize: 18, 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!, 
                style: const TextStyle(color: Color(0xFFa0a0a0), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плашка статуса (нет интернета / оффлайн)
class StatusToast extends StatefulWidget {
  final bool isVisible;
  final String title;
  final VoidCallback? onDismiss;

  const StatusToast({
    super.key,
    required this.isVisible,
    this.title = 'Нет сети',
    this.onDismiss,
  });

  @override
  State<StatusToast> createState() => _StatusToastState();
}

class _StatusToastState extends State<StatusToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.isVisible) {
      _controller.forward();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && widget.isVisible && !_isDragging) {
          _dismiss();
        }
      });
    }
  }

  @override
  void didUpdateWidget(StatusToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.forward();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && widget.isVisible && !_isDragging) {
          _dismiss();
        }
      });
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _dismiss();
    }
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragDistance += details.delta.distance * (details.delta.dx > 0 ? 1 : -1);
      _dragDistance = _dragDistance.clamp(-200.0, 200.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    if (_dragDistance.abs() > 80 || details.velocity.pixelsPerSecond.dy.abs() > 300) {
      _dismiss();
    } else {
      setState(() {
        _dragDistance = 0;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: Offset(0, _dragDistance),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, left: 40, right: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFdc2626).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Утилита для отключения свечения при скролле
class NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}