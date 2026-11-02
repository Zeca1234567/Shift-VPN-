import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0E14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ShiftVpnApp());
}

// ============================================================================
// ЦВЕТОВАЯ ПАЛИТРА И КОНСТАНТЫ ДИЗАЙНА
// ============================================================================
class ShiftColors {
  static const Color bgDark = Color(0xFF0B0E14);
  static const Color cardDark = Color(0xFF131824);
  static const Color cardBorder = Color(0xFF1F293D);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color electricBlue = Color(0xFF1E88E5);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A99AD);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color success = Color(0xFF00E676);

  static const LinearGradient neonGradient = LinearGradient(
    colors: [neonCyan, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ShiftVpnApp extends StatelessWidget {
  const ShiftVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ShiftColors.bgDark,
        primaryColor: ShiftColors.neonCyan,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: ShiftColors.neonCyan,
          secondary: ShiftColors.electricBlue,
          surface: ShiftColors.cardDark,
        ),
      ),
      home: const RootCoordinator(),
    );
  }
}

// ============================================================================
// ГЛОБАЛЬНЫЙ КООРДИНАТОР СОСТОЯНИЯ (АВТОРИЗАЦИЯ <-> ГЛАВНЫЙ ЭКРАН)
// ============================================================================
class RootCoordinator extends StatefulWidget {
  const RootCoordinator({super.key});

  @override
  State<RootCoordinator> createState() => _RootCoordinatorState();
}

class _RootCoordinatorState extends State<RootCoordinator> {
  bool _isAuthenticated = false;
  String _userEmail = '';
  String _userName = '';
  DateTime? _trialEndTime;

  void _completeOnboarding(String email, String name) {
    setState(() {
      _userEmail = email;
      _userName = name;
      _trialEndTime = DateTime.now().add(const Duration(days: 2));
      _isAuthenticated = true;
    });
  }

  void _logout() {
    setState(() {
      _isAuthenticated = false;
      _userEmail = '';
      _userName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _isAuthenticated
          ? MainNavigationShell(
              key: const ValueKey('MainShell'),
              userEmail: _userEmail,
              userName: _userName,
              trialEndTime: _trialEndTime!,
              onLogout: _logout,
            )
          : OnboardingFlowScreen(
              key: const ValueKey('Onboarding'),
              onCompleted: _completeOnboarding,
            ),
    );
  }
}

// ============================================================================
// КАСТОМНЫЙ ЛОГОТИП SHIFT VPN (НЕОНОВАЯ МОЛНИЯ)
// ============================================================================
class ShiftLightningLogo extends StatelessWidget {
  final double size;
  final bool isGlowing;
  final Color? color;

  const ShiftLightningLogo({
    super.key,
    this.size = 64,
    this.isGlowing = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: (color ?? ShiftColors.neonCyan).withOpacity(0.35),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.05,
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _LightningPainter(color: color),
      ),
    );
  }
}

class _LightningPainter extends CustomPainter {
  final Color? color;
  _LightningPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.58, h * 0.08)
      ..lineTo(w * 0.20, h * 0.54)
      ..lineTo(w * 0.48, h * 0.54)
      ..lineTo(w * 0.38, h * 0.92)
      ..lineTo(w * 0.80, h * 0.44)
      ..lineTo(w * 0.52, h * 0.44)
      ..close();

    final paint = Paint()..style = PaintingStyle.fill;

    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = ShiftColors.neonGradient.createShader(
        Rect.fromLTWH(0, 0, w, h),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LightningPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================================
// 1. ЭКРАН ОНБОРДИНГА / АВТОРИЗАЦИИ (3 ШАГА)
// ============================================================================
class OnboardingFlowScreen extends StatefulWidget {
  final void Function(String email, String name) onCompleted;

  const OnboardingFlowScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _step = 0; // 0: Email, 1: OTP, 2: Profile
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  // OTP Контроллеры (4 ячейки)
  final List<TextEditingController> _otpCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(4, (_) => FocusNode());

  Timer? _resendTimer;
  int _secondsLeft = 45;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _secondsLeft = 45;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  void _nextFromEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Введите корректный Email адрес');
      return;
    }
    setState(() {
      _errorText = null;
      _step = 1;
    });
    _startResendTimer();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _otpFocus[0].requestFocus();
    });
  }

  void _verifyOtp() {
    final code = _otpCtrls.map((e) => e.text).join();
    if (code.length < 4) {
      setState(() => _errorText = 'Введите 4-значный код подтверждения');
      return;
    }
    setState(() {
      _errorText = null;
      _step = 2;
    });
  }

  void _finishOnboarding() {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Имя должно содержать минимум 2 символа');
      return;
    }
    widget.onCompleted(_emailCtrl.text.trim(), name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фоновое неоновое пятно сверху
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ShiftColors.neonCyan.withOpacity(0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ShiftLightningLogo(size: 76),
                    const SizedBox(height: 16),
                    const Text(
                      'SHIFT VPN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: ShiftColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Сверхбыстрый туннель нового поколения',
                      style: TextStyle(
                        fontSize: 13,
                        color: ShiftColors.textSecondary.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Индикатор шагов
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        final isActive = index <= _step;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 4,
                          width: index == _step ? 32 : 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isActive
                                ? ShiftColors.neonCyan
                                : ShiftColors.cardBorder,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          ShiftColors.neonCyan.withOpacity(0.5),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // Карточка шага с плавной анимацией
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ShiftColors.cardDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ShiftColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.08, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildEmailStep();
      case 1:
        return _buildOtpStep();
      case 2:
      default:
        return _buildProfileStep();
    }
  }

  // ШАГ А: Ввод Email
  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('StepEmail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Вход в систему',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Укажите ваш Email для мгновенной авторизации без пароля',
          style: TextStyle(fontSize: 13, color: ShiftColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _NeonTextField(
          controller: _emailCtrl,
          hintText: 'Введите Email',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _nextFromEmail(),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: ShiftColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        _NeonPrimaryButton(
          label: 'Получить код',
          icon: Icons.bolt_rounded,
          onTap: _nextFromEmail,
        ),
      ],
    );
  }

  // ШАГ Б: Ввод OTP кода
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('StepOtp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _errorText = null;
                _step = 0;
              }),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            const Text(
              'Код подтверждения',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Код отправлен на указанную почту:\n${_emailCtrl.text}',
          style: const TextStyle(
            fontSize: 13,
            color: ShiftColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // 4 ячейки OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 62,
              height: 68,
              child: TextField(
                controller: _otpCtrls[index],
                focusNode: _otpFocus[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ShiftColors.neonCyan,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: ShiftColors.bgDark,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ShiftColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: ShiftColors.neonCyan,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 3) {
                    _otpFocus[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _otpFocus[index - 1].requestFocus();
                  }
                  if (_otpCtrls.every((c) => c.text.isNotEmpty)) {
                    _verifyOtp();
                  }
                },
              ),
            );
          }),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: ShiftColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),

        // Таймер повторной отправки
        Center(
          child: _secondsLeft > 0
              ? Text(
                  'Отправить код повторно через 00:${_secondsLeft.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ShiftColors.textSecondary,
                  ),
                )
              : TextButton(
                  onPressed: _startResendTimer,
                  child: const Text(
                    'Отправить код повторно',
                    style: TextStyle(
                      color: ShiftColors.neonCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _NeonPrimaryButton(
          label: 'Подтвердить код',
          icon: Icons.verified_outlined,
          onTap: _verifyOtp,
        ),
      ],
    );
  }

  // ШАГ В: Создание профиля
  Widget _buildProfileStep() {
    return Column(
      key: const ValueKey('StepProfile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Создание профиля',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Почти готово! Как к вам обращаться?',
          style: TextStyle(fontSize: 13, color: ShiftColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _NeonTextField(
          controller: _nameCtrl,
          hintText: 'Придумайте ваше имя / никнейм',
          icon: Icons.person_outline_rounded,
          onSubmitted: (_) => _finishOnboarding(),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: ShiftColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),

        // Плашка пробного периода
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                ShiftColors.neonCyan.withOpacity(0.15),
                ShiftColors.electricBlue.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: ShiftColors.neonCyan.withOpacity(0.45),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.electric_bolt_rounded,
                color: ShiftColors.neonCyan,
                size: 26,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Вам начислен бесплатный пробный период: 2 дня безлимита ⚡️',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ShiftColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _NeonPrimaryButton(
          label: 'Начать пользоваться',
          icon: Icons.rocket_launch_rounded,
          onTap: _finishOnboarding,
        ),
      ],
    );
  }
}

// ============================================================================
// ОБОЛОЧКА С НИЖНЕЙ НАВИГАЦИЕЙ (ГЛАВНАЯ / ПРОФИЛЬ)
// ============================================================================
enum VpnConnectionState { disconnected, connecting, connected }

class MainNavigationShell extends StatefulWidget {
  final String userEmail;
  final String userName;
  final DateTime trialEndTime;
  final VoidCallback onLogout;

  const MainNavigationShell({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.trialEndTime,
    required this.onLogout,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  VpnConnectionState _vpnState = VpnConnectionState.disconnected;

  // Динамические показатели сети
  int _pingMs = 0;
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  Timer? _telemetryTimer;
  final Random _rnd = Random();

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  void _toggleVpn() {
    if (_vpnState == VpnConnectionState.disconnected) {
      setState(() => _vpnState = VpnConnectionState.connecting);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _vpnState = VpnConnectionState.connected;
          _pingMs = 28;
          _downloadSpeed = 142.4;
          _uploadSpeed = 86.1;
        });
        _startTelemetrySimulation();
      });
    } else if (_vpnState == VpnConnectionState.connected) {
      _telemetryTimer?.cancel();
      setState(() {
        _vpnState = VpnConnectionState.disconnected;
        _pingMs = 0;
        _downloadSpeed = 0.0;
        _uploadSpeed = 0.0;
      });
    }
  }

  void _startTelemetrySimulation() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _vpnState != VpnConnectionState.connected) return;
      setState(() {
        _pingMs = 24 + _rnd.nextInt(9);
        _downloadSpeed = 125.0 + _rnd.nextDouble() * 45.0;
        _uploadSpeed = 70.0 + _rnd.nextDouble() * 25.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        vpnState: _vpnState,
        pingMs: _pingMs,
        downloadSpeed: _downloadSpeed,
        uploadSpeed: _uploadSpeed,
        onToggleVpn: _toggleVpn,
      ),
      ProfileScreen(
        userName: widget.userName,
        userEmail: widget.userEmail,
        trialEndTime: widget.trialEndTime,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: ShiftColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ShiftColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.shield_outlined,
              activeIcon: Icons.bolt_rounded,
              label: 'Главная',
              isSelected: _selectedIndex == 0,
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            _BottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Профиль',
              isSelected: _selectedIndex == 1,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? ShiftColors.neonCyan.withOpacity(0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color:
                  isSelected ? ShiftColors.neonCyan : ShiftColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? ShiftColors.neonCyan
                    : ShiftColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. ГЛАВНЫЙ ЭКРАН (HOME SCREEN)
// ============================================================================
class HomeScreen extends StatefulWidget {
  final VpnConnectionState vpnState;
  final int pingMs;
  final double downloadSpeed;
  final double uploadSpeed;
  final VoidCallback onToggleVpn;

  const HomeScreen({
    super.key,
    required this.vpnState,
    required this.pingMs,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.onToggleVpn,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.vpnState == VpnConnectionState.connected;
    final isConnecting = widget.vpnState == VpnConnectionState.connecting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Верхняя панель
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    ShiftLightningLogo(size: 32, isGlowing: false),
                    SizedBox(width: 10),
                    Text(
                      'Shift VPN',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: ShiftColors.neonCyan.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ShiftColors.neonCyan.withOpacity(0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: ShiftColors.neonCyan,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Пробный период: осталось 2 дня',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: ShiftColors.neonCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Центральная неоновая кнопка с пульсирующим свечением
            GestureDetector(
              onTap: isConnecting ? null : widget.onToggleVpn,
              child: SizedBox(
                width: 250,
                height: 250,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double pulse = _pulseController.value;
                    final Color activeColor = isConnected
                        ? ShiftColors.neonCyan
                        : isConnecting
                            ? ShiftColors.electricBlue
                            : ShiftColors.textSecondary;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Внешние волны пульсации (когда подключено или подключается)
                        if (isConnected || isConnecting) ...[
                          Container(
                            width: 175 + (pulse * 75),
                            height: 175 + (pulse * 75),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    activeColor.withOpacity((1 - pulse) * 0.55),
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 175 + (((pulse + 0.5) % 1.0) * 75),
                            height: 175 + (((pulse + 0.5) % 1.0) * 75),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor.withOpacity(
                                  (1 - ((pulse + 0.5) % 1.0)) * 0.14),
                            ),
                          ),
                        ],

                        // Основная круглая кнопка
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ShiftColors.cardDark,
                            border: Border.all(
                              color: isConnected
                                  ? ShiftColors.neonCyan
                                  : isConnecting
                                      ? ShiftColors.electricBlue
                                      : ShiftColors.cardBorder,
                              width: isConnected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isConnected
                                    ? ShiftColors.neonCyan.withOpacity(0.42)
                                    : isConnecting
                                        ? ShiftColors.electricBlue
                                            .withOpacity(0.3)
                                        : Colors.black.withOpacity(0.5),
                                blurRadius: isConnected ? 42 : 20,
                                spreadRadius: isConnected ? 6 : 0,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShiftLightningLogo(
                                size: 68,
                                isGlowing: isConnected || isConnecting,
                                color: isConnected
                                    ? null
                                    : isConnecting
                                        ? ShiftColors.electricBlue
                                        : ShiftColors.textSecondary
                                            .withOpacity(0.45),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isConnected
                                    ? 'ПОДКЛЮЧЕНО'
                                    : isConnecting
                                        ? 'ПОДКЛЮЧЕНИЕ...'
                                        : 'ВКЛЮЧИТЬ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: isConnected
                                      ? ShiftColors.neonCyan
                                      : ShiftColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Текстовый индикатор статуса
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(widget.vpnState),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected
                      ? ShiftColors.neonCyan.withOpacity(0.1)
                      : ShiftColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected
                        ? ShiftColors.neonCyan.withOpacity(0.4)
                        : ShiftColors.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? ShiftColors.neonCyan
                            : isConnecting
                                ? Colors.amber
                                : ShiftColors.danger,
                        boxShadow: [
                          BoxShadow(
                            color: isConnected
                                ? ShiftColors.neonCyan
                                : ShiftColors.danger,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isConnected
                          ? 'Соединение защищено (VLESS)'
                          : isConnecting
                              ? 'Установка VLESS Reality туннеля...'
                              : 'Защита отключена',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isConnected
                            ? ShiftColors.textPrimary
                            : ShiftColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Карточка локации и протокола
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: ShiftColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ShiftColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShiftColors.neonCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.public_rounded,
                      color: ShiftColors.neonCyan,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Нидерланды • Амстердам #1',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Протокол: VLESS Reality (XTLS-RPRX-Vision)',
                          style: TextStyle(
                            fontSize: 12,
                            color: ShiftColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: ShiftColors.textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Показатели Ping, Download, Upload
            Row(
              children: [
                Expanded(
                  child: _TelemetryCard(
                    title: 'ПИНГ',
                    value: isConnected ? '${widget.pingMs}' : '--',
                    unit: 'мс',
                    icon: Icons.network_ping_rounded,
                    accentColor: ShiftColors.neonCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TelemetryCard(
                    title: 'СКАЧИВАНИЕ',
                    value: isConnected
                        ? widget.downloadSpeed.toStringAsFixed(1)
                        : '0.0',
                    unit: 'Мбит/с',
                    icon: Icons.south_west_rounded,
                    accentColor: ShiftColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TelemetryCard(
                    title: 'ЗАГРУЗКА',
                    value: isConnected
                        ? widget.uploadSpeed.toStringAsFixed(1)
                        : '0.0',
                    unit: 'Мбит/с',
                    icon: Icons.north_east_rounded,
                    accentColor: ShiftColors.electricBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accentColor;

  const _TelemetryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShiftColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ShiftColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ShiftColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ShiftColors.textPrimary,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: ShiftColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. ЭКРАН ПРОФИЛЯ (PROFILE SCREEN)
// ============================================================================
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final DateTime trialEndTime;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.trialEndTime,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Timer _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final diff = widget.trialEndTime.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hoursч : $minutesм : $secondsс';
  }

  void _showTariffsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ShiftColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Тарифы Shift VPN ⚡️',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Безлимитный трафик на скорости до 10 Гбит/с, протокол VLESS Reality.',
              style: TextStyle(fontSize: 13, color: ShiftColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _buildTariffTile('1 Месяц', '199 ₽ / мес', false),
            const SizedBox(height: 12),
            _buildTariffTile('1 Год (-40%)', '1 490 ₽ / год', true),
            const SizedBox(height: 20),
            _NeonPrimaryButton(
              label: 'Закрыть',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffTile(String title, String price, bool isBest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShiftColors.bgDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest ? ShiftColors.neonCyan : ShiftColors.cardBorder,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            price,
            style: const TextStyle(
              color: ShiftColors.neonCyan,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ShiftColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            ShiftLightningLogo(size: 32, isGlowing: false),
            SizedBox(width: 12),
            Text('О приложении'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Версия: 1.0.0 (Build 100)'),
            SizedBox(height: 8),
            Text('Ядро: Xray-core VLESS Reality'),
            SizedBox(height: 8),
            Text(
              'Шифрование устойчиво к DPI-анализу и блокировкам трафика.',
              style: TextStyle(color: ShiftColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Понятно',
              style: TextStyle(color: ShiftColors.neonCyan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isNotEmpty
        ? widget.userName.trim()[0].toUpperCase()
        : 'S';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Профиль',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),

            // Шапка пользователя
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ShiftColors.cardDark,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ShiftColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ShiftColors.neonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: ShiftColors.neonCyan.withOpacity(0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: ShiftColors.bgDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.userEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ShiftColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Карточка подписки
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    ShiftColors.neonCyan.withOpacity(0.16),
                    ShiftColors.cardDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: ShiftColors.neonCyan.withOpacity(0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: ShiftColors.neonCyan.withOpacity(0.1),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'СТАТУС ПОДПИСКИ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: ShiftColors.neonCyan,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ShiftColors.neonCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACTIVE ⚡️',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ShiftColors.neonCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Пробный доступ (2 дня)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: ShiftColors.bgDark.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ShiftColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.hourglass_bottom_rounded,
                          color: ShiftColors.neonCyan,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'До конца триала:',
                          style: TextStyle(
                            fontSize: 13,
                            color: ShiftColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatCountdown(_remaining),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ShiftColors.neonCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _NeonPrimaryButton(
                    label: 'Продлить доступ / Тарифы',
                    icon: Icons.workspace_premium_rounded,
                    onTap: _showTariffsModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'НАСТРОЙКИ И ПОДДЕРЖКА',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: ShiftColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            _ProfileActionTile(
              icon: Icons.support_agent_rounded,
              title: 'Связаться с поддержкой',
              subtitle: 'Telegram-бот 24/7 (@shift_vpn_support)',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Переход в Telegram поддержки Shift VPN...'),
                    backgroundColor: ShiftColors.cardDark,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.info_outline_rounded,
              title: 'О приложении',
              subtitle: 'Версия 1.0.0 • Протокол VLESS Reality',
              onTap: _showAboutDialog,
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.logout_rounded,
              title: 'Выйти из аккаунта',
              subtitle: 'Завершить текущую сессию',
              isDestructive: true,
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? ShiftColors.danger : ShiftColors.neonCyan;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ShiftColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? ShiftColors.danger.withOpacity(0.3)
                : ShiftColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? ShiftColors.danger
                          : ShiftColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ShiftColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive
                  ? ShiftColors.danger
                  : ShiftColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ПЕРЕИСПОЛЬЗУЕМЫЕ UI-КОМПОНЕНТЫ (КНОПКИ И ПОЛЯ ВВОДА)
// ============================================================================
class _NeonTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _NeonTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: ShiftColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: ShiftColors.textSecondary),
        prefixIcon: Icon(icon, color: ShiftColors.neonCyan, size: 20),
        filled: true,
        fillColor: ShiftColors.bgDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: ShiftColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: ShiftColors.neonCyan, width: 1.8),
        ),
      ),
    );
  }
}

class _NeonPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _NeonPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: ShiftColors.neonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ShiftColors.neonCyan.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ShiftColors.bgDark, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ShiftColors.bgDark,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
