import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../core/storage_info_system.dart';
import '../core/data_system.dart';


// ========== ЭКРАН НАСТРОЕК ==========

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  
  const SettingsScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataSystem _dataSystem = DataSystem();  // ← CacheSystem → DataSystem
  final StorageInfoSystem _storageSystem = StorageInfoSystem();
  
  int _dataSize = 0;  // ← _cacheSize → _dataSize
  int _totalStorage = 0;
  int _freeStorage = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _initDataAndLoadSize();  // ← переименовал
  }

  Future<void> _initDataAndLoadSize() async {  // ← переименовал
    await _dataSystem.init();  // ← _cacheSystem → _dataSystem
    await _loadDataSize();  // ← переименовал
  }

  Future<void> _loadDataSize() async {  // ← _loadCacheSize → _loadDataSize
    setState(() => _isLoading = true);
    
    try {
      final dataSize = await _storageSystem.getCacheSize();  // метод остаётся getCacheSize
      
      // Получаем информацию о хранилище через path_provider
      int totalStorage = 0;
      int freeStorage = 0;
      
      try {
        final directory = await getApplicationDocumentsDirectory();
        
        // Для мобильных платформ используем системную команду df
        if (Platform.isAndroid || Platform.isIOS) {
          final result = await Process.run('df', ['-k', directory.path]);
          if (result.exitCode == 0) {
            final lines = result.stdout.toString().split('\n');
            if (lines.length > 1) {
              final parts = lines[1].trim().split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                totalStorage = int.tryParse(parts[1]) ?? 0; // в KB
                freeStorage = int.tryParse(parts[3]) ?? 0; // в KB
                // Конвертируем в байты
                totalStorage *= 1024;
                freeStorage *= 1024;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Не удалось получить информацию о хранилище: $e');
      }
      
      setState(() {
        _dataSize = dataSize;  // ← _cacheSize → _dataSize
        _totalStorage = totalStorage > 0 ? totalStorage : 1024 * 1024 * 1024;
        _freeStorage = freeStorage > 0 ? freeStorage : 512 * 1024 * 1024;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Ошибка в _loadDataSize: $e');
      setState(() {
        _dataSize = 0;
        _totalStorage = 1024 * 1024 * 1024;
        _freeStorage = 512 * 1024 * 1024;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearData() async {  // ← _clearCache → _clearData
    setState(() {
      _isClearing = true;
    });
    
    try {
      await _storageSystem.clearAllCache(_dataSystem);  // ← _cacheSystem → _dataSystem
      await _loadDataSize();  // ← переименовал
      setState(() => _isClearing = false);
    } catch (e) {
      debugPrint('❌ Ошибка в _clearData: $e');
      setState(() => _isClearing = false);
    }
  }

  Future<void> _reportBug() async {
  final Uri telegramAppUri = Uri.parse('tg://resolve?domain=wptf80x');
  final Uri telegramWebUri = Uri.parse('https://t.me/wptf80x');
  
  try {
    if (await canLaunchUrl(telegramAppUri)) {
      await launchUrl(telegramAppUri, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(telegramWebUri, mode: LaunchMode.externalApplication);
  } catch (e) {
    try {
      await launchUrl(telegramWebUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Не удалось открыть Telegram: $e');
    }
  }
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080808), // Очень темный, почти черный
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDataSection(),
                      const SizedBox(height: 24),
                      _buildReportSection(),
                      const SizedBox(height: 24),
                      _buildAboutSection(),
                    ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBackPressed ?? () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Настройки',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {  // ← _buildCacheSection → _buildDataSection
    final dataSizeText = _isLoading 
        ? 'Загрузка...' 
        : _storageSystem.formatSize(_dataSize);  // ← _cacheSize → _dataSize
    
    final totalStorageText = _isLoading 
        ? '...' 
        : _storageSystem.formatSize(_totalStorage);
    
    final freeStorageText = _isLoading 
        ? '...' 
        : _storageSystem.formatSize(_freeStorage);
    
    // Прогресс — просто занятое место относительно всего хранилища
    final progress = _isClearing 
        ? 0.0 
        : (_totalStorage > 0 ? (_dataSize / _totalStorage).clamp(0.0, 1.0) : 0.0);
    
    
    return FadeInWrapper(
      duration: const Duration(milliseconds: 400),
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF3b82f6).withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.storage_rounded,
                          color: Color(0xFF3b82f6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Хранилище',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Использование памяти устройства',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFa0a0a0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Шкала использования хранилища
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок с процентом
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Занято приложением',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                dataSizeText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3b82f6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Прогресс-бар — просто занятое место
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF3b82f6),  // ← всегда синий
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Информация о хранилище
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStorageInfoItem(
                                icon: Icons.phone_android_rounded,
                                label: 'Всего',
                                value: totalStorageText,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            Expanded(
                              child: _buildStorageInfoItem(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Свободно',
                                value: freeStorageText,
                                valueColor: const Color(0xFF10b981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      Text(
                        'Данные автоматически обновляются каждые 30 минут',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || _isClearing || _dataSize == 0 
                          ? null 
                          : _clearData,  // ← _clearCache → _clearData
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _isClearing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Очистить данные',  // ← "кеш" → "данные"
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStorageInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = const Color(0xFF3b82f6),
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.5),
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildReportSection() {
    return FadeInWrapper(
      duration: const Duration(milliseconds: 500),
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.bug_report_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Помощь и обратная связь',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Сообщите о проблеме в Telegram',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFa0a0a0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildMenuButton(
                    icon: Icons.send_rounded,
                    label: 'Написать в Telegram',
                    onTap: _reportBug,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return FadeInWrapper(
      duration: const Duration(milliseconds: 600),
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'О приложении',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Версия 3.0.0 BETA! ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFa0a0a0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Center(
                    child: Text(
                      '© 2026 Weather App',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ ==========

class FadeInWrapper extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;
  final Curve curve;

  const FadeInWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offsetY = 0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}