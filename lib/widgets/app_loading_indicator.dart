import 'package:flutter/material.dart';

/// Единственный индикатор загрузки в приложении.
///
/// Выглядит ровно так же, как индикатор pull-to-refresh у [RefreshIndicator]:
/// белая дуга толщиной 2 без подложки. Поэтому одинаково смотрится и при
/// потягивании экрана вниз, и в любом другом месте — свой стиль спиннеров
/// больше не расходится по экранам.
///
/// Размер по умолчанию совпадает с боксом индикатора pull-to-refresh.
/// В тесных местах (кнопка, строка списка) передавайте меньший [size].
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size = 40,
    this.color = Colors.white,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Тот же самый индикатор, но по центру доступной области.
///
/// Используется для полноэкранной загрузки, чтобы состояние «ждём данные»
/// выглядело один в один, включая отступы.
class AppLoadingOverlay extends StatelessWidget {
  final double size;

  const AppLoadingOverlay({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Center(child: AppLoadingIndicator(size: size));
  }
}
