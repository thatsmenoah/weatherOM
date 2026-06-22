import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../core/storage_info_system.dart';
import '../core/data_system.dart';
import '../constants/settings_const.dart';

// ========== ЭКРАН НАСТРОЕК ==========

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SettingsScreen({super.key, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataSystem _dataSystem = DataSystem();
  final StorageInfoSystem _storageSystem = StorageInfoSystem();

  int _dataSize = 0;
  int _totalStorage = 0;
  int _freeStorage = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _initDataAndLoadSize();
  }

  Future<void> _initDataAndLoadSize() async {
    await _dataSystem.init();
    await _loadDataSize();
  }

  Future<void> _loadDataSize() async {
    setState(() => _isLoading = true);

    try {
      final dataSize = await _storageSystem.getCacheSize();

      int totalStorage = 0;
      int freeStorage = 0;

      try {
        final directory = await getApplicationDocumentsDirectory();

        if (Platform.isAndroid || Platform.isIOS) {
          final result = await Process.run('df', ['-k', directory.path]);
          if (result.exitCode == 0) {
            final lines = result.stdout.toString().split('\n');
            if (lines.length > 1) {
              final parts = lines[1].trim().split(RegExp(r'\s+'));
              if (parts.length >= 4) {
                totalStorage = int.tryParse(parts[1]) ?? 0;
                freeStorage = int.tryParse(parts[3]) ?? 0;
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
        _dataSize = dataSize;
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

  Future<void> _clearData() async {
    setState(() => _isClearing = true);

    try {
      await _storageSystem.clearAllCache(_dataSystem);
      await _loadDataSize();
      setState(() => _isClearing = false);
    } catch (e) {
      debugPrint('❌ Ошибка в _clearData: $e');
      setState(() => _isClearing = false);
    }
  }

  Future<void> _reportBug() async {
    final Uri telegramAppUri = Uri.parse('tg://resolve?domain=${SettingsConst.telegramUsername}');
    final Uri telegramWebUri = Uri.parse('https://t.me/${SettingsConst.telegramUsername}');

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
        decoration: const BoxDecoration(color: SettingsConst.bgScreen),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: SettingsConst.padScreen,
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
      padding: SettingsConst.padHeader,
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBackPressed ?? () => Navigator.pop(context),
            child: Container(
              width: SettingsConst.headerButtonSize,
              height: SettingsConst.headerButtonSize,
              decoration: BoxDecoration(
                color: SettingsConst.bgButton,
                borderRadius: BorderRadius.circular(SettingsConst.radiusHeaderButton),
                border: SettingsConst.defaultBorder,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: SettingsConst.textPrimary, size: SettingsConst.headerIconSize),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Настройки', style: SettingsConst.tsHeaderTitle)),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    final dataSizeText = _isLoading ? 'Загрузка...' : _storageSystem.formatSize(_dataSize);
    final totalStorageText = _isLoading ? '...' : _storageSystem.formatSize(_totalStorage);
    final freeStorageText = _isLoading ? '...' : _storageSystem.formatSize(_freeStorage);
    final progress = _isClearing ? 0.0 : (_totalStorage > 0 ? (_dataSize / _totalStorage).clamp(0.0, 1.0) : 0.0);

    return FadeInWrapper(
      duration: SettingsConst.durSectionFade,
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: SettingsConst.bgCard,
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          border: SettingsConst.defaultBorder,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: SettingsConst.blurGlass, sigmaY: SettingsConst.blurGlass),
            child: Padding(
              padding: SettingsConst.padCardContent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: SettingsConst.sectionIconBoxSize,
                        height: SettingsConst.sectionIconBoxSize,
                        decoration: BoxDecoration(
                          color: SettingsConst.bgIconBox,
                          borderRadius: BorderRadius.circular(SettingsConst.radiusIconBox),
                          border: Border.all(color: SettingsConst.accentBlue.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.storage_rounded, color: SettingsConst.accentBlue, size: SettingsConst.sectionIconSize),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Хранилище', style: SettingsConst.tsSectionTitle),
                            SizedBox(height: 2),
                            Text('Использование памяти устройства', style: SettingsConst.tsSectionSubtitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Занято приложением', style: SettingsConst.tsStorageLabel),
                          Row(children: [Text(dataSizeText, style: SettingsConst.tsStorageValue)]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: SettingsConst.progressBarHeight,
                        decoration: BoxDecoration(
                          color: SettingsConst.bgButton,
                          borderRadius: BorderRadius.circular(SettingsConst.radiusProgressBar),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(SettingsConst.radiusProgressBar),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(SettingsConst.accentBlue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: SettingsConst.padInfoBox,
                        decoration: BoxDecoration(
                          color: SettingsConst.bgInfoBox,
                          borderRadius: BorderRadius.circular(SettingsConst.radiusInfoBox),
                          border: SettingsConst.subtleBorder,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStorageInfoItem(icon: Icons.phone_android_rounded, label: 'Всего', value: totalStorageText),
                            ),
                            Container(
                              width: SettingsConst.dividerWidth,
                              height: SettingsConst.dividerHeight,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            Expanded(
                              child: _buildStorageInfoItem(
                                icon: Icons.check_circle_outline_rounded,
                                label: 'Свободно',
                                value: freeStorageText,
                                valueColor: SettingsConst.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Данные автоматически обновляются каждые 30 минут', style: SettingsConst.tsFooterHint),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || _isClearing || _dataSize == 0 ? null : _clearData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SettingsConst.bgButton,
                        foregroundColor: SettingsConst.textPrimary,
                        disabledBackgroundColor: SettingsConst.bgButtonDisabled,
                        disabledForegroundColor: SettingsConst.textDim,
                        padding: SettingsConst.padButton,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SettingsConst.radiusButton),
                          side: SettingsConst.defaultBorderSide,
                        ),
                        elevation: 0,
                      ),
                      child: _isClearing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(SettingsConst.textPrimary),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: SettingsConst.textPrimary),
                                SizedBox(width: 8),
                                Text('Очистить данные', style: SettingsConst.tsButtonText),
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
    Color valueColor = SettingsConst.accentBlue,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: SettingsConst.infoIconSize),
        const SizedBox(height: 4),
        Text(label, style: SettingsConst.tsInfoItemLabel),
        const SizedBox(height: 2),
        Text(value, style: SettingsConst.tsInfoItemValue.copyWith(color: valueColor)),
      ],
    );
  }

  Widget _buildReportSection() {
    return FadeInWrapper(
      duration: SettingsConst.durSectionFade2,
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: SettingsConst.bgCard,
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          border: SettingsConst.defaultBorder,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: SettingsConst.blurGlass, sigmaY: SettingsConst.blurGlass),
            child: Padding(
              padding: SettingsConst.padCardContent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: SettingsConst.sectionIconBoxSize,
                        height: SettingsConst.sectionIconBoxSize,
                        decoration: BoxDecoration(
                          color: SettingsConst.bgIconBox,
                          borderRadius: BorderRadius.circular(SettingsConst.radiusIconBox),
                          border: SettingsConst.defaultBorder,
                        ),
                        child: const Icon(Icons.bug_report_rounded, color: SettingsConst.textPrimary, size: SettingsConst.sectionIconSize),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Помощь и обратная связь', style: SettingsConst.tsSectionTitle),
                            SizedBox(height: 2),
                            Text('Сообщите о проблеме в Telegram', style: SettingsConst.tsSectionSubtitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildMenuButton(icon: Icons.send_rounded, label: 'Написать в Telegram', onTap: _reportBug),
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
      duration: SettingsConst.durSectionFade3,
      offsetY: 10,
      child: Container(
        decoration: BoxDecoration(
          color: SettingsConst.bgCard,
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          border: SettingsConst.defaultBorder,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SettingsConst.radiusCard),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: SettingsConst.blurGlass, sigmaY: SettingsConst.blurGlass),
            child: Padding(
              padding: SettingsConst.padCardContent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: SettingsConst.sectionIconBoxSize,
                        height: SettingsConst.sectionIconBoxSize,
                        decoration: BoxDecoration(
                          color: SettingsConst.bgIconBox,
                          borderRadius: BorderRadius.circular(SettingsConst.radiusIconBox),
                          border: SettingsConst.defaultBorder,
                        ),
                        child: const Icon(Icons.info_outline_rounded, color: SettingsConst.textPrimary, size: SettingsConst.sectionIconSize),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('О приложении', style: SettingsConst.tsSectionTitle),
                            SizedBox(height: 2),
                            Text(SettingsConst.appVersion, style: SettingsConst.tsSectionSubtitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text(SettingsConst.copyrightText, style: SettingsConst.tsCopyright)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SettingsConst.radiusButton),
        child: Container(
          padding: SettingsConst.padMenuButton,
          decoration: BoxDecoration(
            color: SettingsConst.bgMenuButton,
            borderRadius: BorderRadius.circular(SettingsConst.radiusButton),
            border: SettingsConst.subtleBorder06,
          ),
          child: Row(
            children: [
              Icon(icon, color: SettingsConst.textPrimary, size: SettingsConst.menuIconSize),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: SettingsConst.tsMenuButtonText)),
              Icon(Icons.arrow_forward_ios_rounded, color: SettingsConst.textDim, size: SettingsConst.menuArrowSize),
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
          child: Transform.translate(offset: Offset(0, offsetY * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}