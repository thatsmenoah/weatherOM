import 'package:flutter/material.dart';

// ========== СИСТЕМА ЗАГРУЗКИ ==========

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

// ========== ВИДЖЕТЫ ЗАГРУЗКИ ==========

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
  final String subtitle;
  final IconData icon;
  final VoidCallback? onDismiss;
  final bool isFallback; // НОВОЕ: если true - жёлтый цвет, если false - красный
  
  const StatusToast({
    super.key,
    required this.isVisible,
    this.title = 'Нет интернета',
    this.subtitle = 'Используем сохранённые данные',
    this.icon = Icons.wifi_off,
    this.onDismiss,
    this.isFallback = false,
  });
  
  @override
  State<StatusToast> createState() => _StatusToastState();
}

class _StatusToastState extends State<StatusToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    }
  }
  
  @override
  void didUpdateWidget(StatusToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.forward();
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && widget.isVisible) {
          _hide();
        }
      });
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hide();
    }
  }
  
  void _hide() {
    _controller.reverse().then((_) {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Выбираем цвета в зависимости от типа уведомления
    final isFallback = widget.isFallback;
    final bgColor = isFallback 
        ? const Color(0xFFF59E0B) // Жёлтый для fallback
        : const Color(0xFFdc2626); // Красный для ошибок
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 50, right: 12),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _hide,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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