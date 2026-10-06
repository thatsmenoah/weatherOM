import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/widgets/app_loading_indicator.dart';

void main() {
  testWidgets('AppLoadingIndicator рисует CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingIndicator(size: 24))),
    );

    // 1. Ищем встроенный CircularProgressIndicator
    final progressFinder = find.byType(CircularProgressIndicator);
    expect(progressFinder, findsOneWidget);
    
    // 2. Явно кастим к типу CircularProgressIndicator, чтобы получить доступ к strokeWidth и color
    final indicator = tester.widget<CircularProgressIndicator>(progressFinder);
    
    // 3. Проверяем strokeWidth
    expect(indicator.strokeWidth, 2.0);
    
    // 4. Сравниваем цвета напрямую как объекты, избегая устаревшего .value
    expect(indicator.valueColor?.value, Colors.white);
  });

  testWidgets('AppLoadingIndicator уважает переданный размер', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingIndicator(size: 36))),
    );

    final box = tester.renderObject<RenderBox>(find.byType(AppLoadingIndicator));
    expect(box.size.width, 36);
    expect(box.size.height, 36);
  });

  testWidgets('AppLoadingOverlay центрирует индикатор', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingOverlay(size: 28))),
    );

    final centered = find.ancestor(
      of: find.byType(AppLoadingIndicator),
      matching: find.byType(Center),
    );
    expect(centered, findsOneWidget);
  });
}
