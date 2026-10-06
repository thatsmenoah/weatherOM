import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'firebase_options.dart';
import 'screen/weather_screen.dart';
import 'screen/another_screen.dart';
import 'screen/settings_screen.dart';
import 'screen/search_screen.dart';
import 'core/locale_manager.dart';
import 'core/app_version.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';
import 'widgets/update_pill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ========== ЗАГРУЖАЕМ .env ==========
  await dotenv.load(fileName: ".env");
  // ====================================

  // ========== FIREBASE ==========
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Анонимный вход: не блокируем запуск UI — если сети нет,
  // приложение всё равно откроется, а uid появится при следующем запуске.
  AuthService.instance.ensureSignedIn();
  // ==============================

  await LocaleManager().init();
  await AppVersion.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Cloud',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: Colors.white,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

final GlobalKey<WeatherScreenState> weatherScreenKey =
    GlobalKey<WeatherScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isMenuOpen = false;
  bool _showNav = true;

  late AnimationController _navAnimationController;
  late AnimationController _menuAnimationController;
  late AnimationController _navSlideController;

  late Animation<double> _navAnimation;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuFadeAnimation;
  late Animation<Offset> _menuSlideAnimation;
  late Animation<Offset> _navSlideAnimation;

  double _lastScrollOffset = 0.0;
  static const double _scrollThreshold = 20.0;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey<ActivityScreenState> _activityScreenKey =
      GlobalKey<ActivityScreenState>();
  late final List<Widget> _screens;

  // ===== ОБНОВЛЕНИЕ ПРИЛОЖЕНИЯ =====
  UpdateInfo? _updateInfo;
  UpdatePillState _updateState = UpdatePillState.idle;
  File? _downloadedApk;
  // ==================================

  @override
  void initState() {
    super.initState();

    _screens = [
      WeatherScreen(key: weatherScreenKey),
      ActivityScreen(key: _activityScreenKey),
    ];

    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _navAnimation = CurvedAnimation(
      parent: _navAnimationController,
      curve: Curves.easeOutCubic,
    );
    _navAnimationController.forward();

    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuScaleAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutCubic,
    );
    _menuFadeAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutQuart,
    );
    _menuSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _navSlideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _navSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.20),
    ).animate(CurvedAnimation(
      parent: _navSlideController,
      curve: Curves.easeInOut,
    ));

    _navSlideController.value = 0.0;
    _showNav = true;

    _checkForUpdate();
  }

  @override
  void dispose() {
    _navAnimationController.dispose();
    _menuAnimationController.dispose();
    _navSlideController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuAnimationController.forward();
      } else {
        _menuAnimationController.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
        _menuAnimationController.reverse();
      });
    }
  }

  void _onNavItemTap(int index) {
    HapticFeedback.mediumImpact();
    
    if (index == 1) {
      weatherScreenKey.currentState?.setShakeRefreshEnabled(false);
      _navigateToSearch();
      return;
    }

    setState(() {
      _currentIndex = 0;
      _isMenuOpen = false;
      _menuAnimationController.reverse();
    });
    weatherScreenKey.currentState?.setShakeRefreshEnabled(true);
  }

  void _updateNavPosition(double scrollOffset, bool isScrollingDown) {
    if ((scrollOffset - _lastScrollOffset).abs() < _scrollThreshold) return;

    if (_currentIndex != 0) {
      if (isScrollingDown && _showNav) {
        setState(() {
          _showNav = false;
          _navSlideController.forward();
        });
      } else if (!isScrollingDown && !_showNav) {
        setState(() {
          _showNav = true;
          _navSlideController.reverse();
        });
      }
      _lastScrollOffset = scrollOffset;
      return;
    }

    setState(() {
      if (isScrollingDown && _showNav) {
        _showNav = false;
        _navSlideController.forward();
      } else if (!isScrollingDown && !_showNav) {
        _showNav = true;
        _navSlideController.reverse();
      }
      _lastScrollOffset = scrollOffset;
    });
  }

  void _navigateToSearch() {
    weatherScreenKey.currentState?.setShakeRefreshEnabled(false);
    final weatherState = weatherScreenKey.currentState;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchScreen(
        currentLat: weatherState?.deviceLat,
        currentLon: weatherState?.deviceLon,
        currentName: weatherState?.deviceLocationName,
        onCurrentLocationSelected: () {
          Navigator.pop(context);
          final state = weatherScreenKey.currentState;
          if (state == null) return;
          state.useCurrentLocation().then((coords) {
            if (coords == null || !mounted) return;
            _activityScreenKey.currentState?.setLocation(coords.$1, coords.$2);
          });
        },
        onLocationSelected: (lat, lon, name) {
          weatherScreenKey.currentState?.setLocation(lat, lon, name);
          _activityScreenKey.currentState?.setLocation(lat, lon);
          Navigator.pop(context);
        },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.05, 1.0, curve: Curves.easeOutCubic),
          );
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 370),
        reverseTransitionDuration: const Duration(milliseconds: 370),
      ),
    ).whenComplete(() {
      if (mounted) {
        weatherScreenKey.currentState?.setShakeRefreshEnabled(_currentIndex == 0);
      }
    });
  }

  void _navigateToSettings() {
    weatherScreenKey.currentState?.setShakeRefreshEnabled(false);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.05, 1.0, curve: Curves.easeOutCubic),
          );
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 370),
        reverseTransitionDuration: const Duration(milliseconds: 350),
      ),
    ).whenComplete(() {
      if (mounted) {
        weatherScreenKey.currentState?.setShakeRefreshEnabled(_currentIndex == 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final scrollOffset = notification.metrics.pixels;
                final isScrollingDown = scrollOffset > _lastScrollOffset;
                _updateNavPosition(scrollOffset, isScrollingDown);
              }
              return false;
            },
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),

          _buildBottomNav(),
          if (_isMenuOpen) _buildMenuOverlay(),
        ],
      ),
    );
  }

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: _closeMenu,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 100,
              right: 20,
              child: CompositedTransformFollower(
                link: _layerLink,
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -12),
                child: FadeTransition(
                  opacity: _menuFadeAnimation,
                  child: SlideTransition(
                    position: _menuSlideAnimation,
                    child: ScaleTransition(
                      scale: _menuScaleAnimation,
                      alignment: Alignment.bottomCenter,
                      child: _buildPopupMenu(),
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

  Widget _buildPopupMenu() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.3),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem(
                    icon: Icons.explore,
                    label: LocaleManager().getText('other'),
                    onTap: () => _onMenuItemTap(() {
                      final weatherState = weatherScreenKey.currentState;
                      final lat = weatherState?.currentLat;
                      final lon = weatherState?.currentLon;
                      if (lat != null && lon != null) {
                        _activityScreenKey.currentState?.setLocation(lat, lon);
                      }
                      setState(() => _currentIndex = 1);
                      weatherScreenKey.currentState?.setShakeRefreshEnabled(false);
                    }),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: LocaleManager().getText('settings'),
                    onTap: () => _onMenuItemTap(() => _navigateToSettings()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuItemTap(VoidCallback action) {
    _closeMenu();
    action();
  }

  // ========== ОБНОВЛЕНИЕ ПРИЛОЖЕНИЯ ==========

  /// Спрашивает у Firestore, есть ли версия новее. Нет сети / нет
  /// обновления → кнопка просто не появляется.
  Future<void> _checkForUpdate() async {
    await UpdateService.instance.init();
    // Ждём анонимный вход — Firestore пускает только авторизованных.
    await AuthService.instance.ensureSignedIn();
    final info = await UpdateService.instance.checkForUpdate();
    if (!mounted || info == null) return;

    setState(() {
      _updateInfo = info;
      _updateState = UpdatePillState.idle;
      _downloadedApk = null;
    });
  }

  String get _updateLabel {
    if (_updateState == UpdatePillState.ready) {
      return LocaleManager().getText('update_install');
    }
    return LocaleManager().getText('update');
  }

  Future<void> _onUpdateTap() async {
    if (_updateState == UpdatePillState.downloading) return;

    // Уже скачано — запускаем системный установщик.
    if (_updateState == UpdatePillState.ready) {
      final file = _downloadedApk;
      if (file == null) return;
      final outcome = await UpdateService.instance.installApk(file);
      if (!mounted || outcome == InstallOutcome.opened) return;
      // Установщик не открылся: раньше это было тихо, пользователь ничего не
      // видел и гадал, почему ничего не происходит.
      _showUpdateProblem(LocaleManager().getText('install_failed'));
      return;
    }

    final info = _updateInfo;
    if (info == null) return;

    setState(() => _updateState = UpdatePillState.downloading);
    try {
      final file = await UpdateService.instance.downloadApk(info);
      if (!mounted) return;
      setState(() {
        _downloadedApk = file;
        _updateState = UpdatePillState.ready;
      });
    } catch (e) {
      debugPrint('[Update] download failed: $e');
      if (!mounted) return;
      setState(() => _updateState = UpdatePillState.idle);
      _showUpdateProblem(LocaleManager().getText('update_failed'));
    }
  }

  void _showUpdateProblem(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Кнопка обновления в нижней навигации (или распорка, если обновления нет).
  Widget _buildUpdateSlot() {
    if (_updateInfo == null) return const SizedBox.shrink();
    return UpdatePill(
      label: _updateLabel,
      state: _updateState,
      onTap: _onUpdateTap,
    );
  }

  // ==========================================

  // ========== НИЖНЯЯ НАВИГАЦИЯ ==========
  Widget _buildBottomNav() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 12,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _navSlideAnimation,
        builder: (context, child) {
          final double offsetY = _navSlideAnimation.value.dy * 500;
          return Transform.translate(
            offset: Offset(0, offsetY),
            child: FadeTransition(
              opacity: _navAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Кнопка "Назад"
                    _buildCircleButton(
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                      onTap: () => _onNavItemTap(0),
                    ),
                    
                    const SizedBox(width: 10),

                    // Кнопка-таблетка "Обновление" (или распорка, если обновления нет)
                    Expanded(child: _buildUpdateSlot()),

                    const SizedBox(width: 10),
                    
                    // Кнопка "Поиск" (круглая)
                    _buildCircleButton(
                      child: const Icon(Icons.search_rounded,
                          color: Colors.white, size: 28),
                      onTap: () => _onNavItemTap(1),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Кнопка "Меню"
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: _buildCircleButton(
                        child: _isMenuOpen
                            ? const Icon(Icons.close_rounded,
                                color: Colors.white, size: 28)
                            : _buildBurgerIcon(),
                        onTap: _toggleMenu,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  // =====================================

  Widget _buildBurgerIcon() {
    return SizedBox(
      width: 24,
      height: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Center(
            child: Container(
              width: 24,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 16,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 10,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
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
        child: Center(child: child),
      ),
    );
  }
}