import 'package:flutter/material.dart';
import '../core/locale_manager.dart';

/// Диалог ошибки геолокации
class LocationErrorDialog extends StatelessWidget {
  const LocationErrorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localeManager = LocaleManager();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.92 + (0.08 * opacity),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF080808), // тот же цвет, что на главном экране
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== ИКОНКА =====
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.location_off_outlined,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 20),

              // ===== ЗАГОЛОВОК =====
              Text(
                localeManager.getText('location_error_title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // ===== ТЕКСТ =====
              Text(
                localeManager.getText('location_error_message'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ===== КНОПКА "ХОРОШО" =====
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08), // как у карточек
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      localeManager.getText('ok'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Показать диалог ошибки геолокации
Future<void> showLocationErrorDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => const LocationErrorDialog(),
  );
}