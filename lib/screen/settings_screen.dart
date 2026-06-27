import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

      setState(() {
        _dataSize = dataSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Ошибка в _loadDataSize: $e');
      setState(() {
        _dataSize = 0;
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

  void _showChangelog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const ChangelogSheet(),
    );
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
                        const SizedBox(height: 24),
                        _buildChangelogButton(),
                        const SizedBox(height: 16),
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

  Widget _buildChangelogButton() {
    return FadeInWrapper(
      duration: SettingsConst.durSectionFade3,
      offsetY: 10,
      child: _buildMenuButton(
        icon: Icons.auto_awesome_rounded,
        label: 'Что нового?',
        onTap: _showChangelog,
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

// ========== CHANGELOG SHEET ==========

class ChangelogSheet extends StatelessWidget {
  const ChangelogSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
          left: BorderSide(color: Color(0xFF2A2A2A), width: 1),
          right: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Что нового?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  SettingsConst.changelogCurrentVersion,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFa0a0a0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildChangelogContent(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChangelogContent() {
    final lines = SettingsConst.changelogText.split('\n');
    final List<TextSpan> spans = [];

    for (final line in lines) {
      if (line.startsWith('0.8.') && line.length < 10) {
        spans.add(TextSpan(
          text: '$line\n',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.6,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$line\n',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFa0a0a0),
            height: 1.6,
          ),
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
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