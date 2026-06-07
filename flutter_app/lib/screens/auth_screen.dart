import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum _AuthScreen {
  welcome,
  register,
  otp,
  verifySuccess,
  forgotPassword,
  resetLinkSent,
  newPassword,
}

class AuthScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  const AuthScreen({super.key, this.onBack, this.onSkip});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  _AuthScreen _currentScreen = _AuthScreen.welcome;
  late TabController _tabController;

  bool _loading = false;
  bool _otpVerified = false; // guard: prevent double-submit after success
  bool _obscureLogin = true;
  bool _obscureReg = true;

  // Login
  final _loginIdentifier = TextEditingController();
  final _loginPassword = TextEditingController();

  // Register
  final _regName = TextEditingController();
  final _regPhone = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();

  // OTP (4 individual boxes — backend generates 4-digit OTP)
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(4, (_) => FocusNode());

  // State
  bool _isResetFlow = false;
  String? _pendingUserId;
  String? _pendingOtp;
  String? _pendingPhone;

  // Forgot / New password
  final _forgotIdentifierController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifier.dispose();
    _loginPassword.dispose();
    _regName.dispose();
    _regPhone.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _forgotIdentifierController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  String get _otpValue =>
      _otpControllers.map((c) => c.text).join();

  void _clearOtpBoxes() {
    for (var c in _otpControllers) c.clear();
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────────────

  /// Normalize a phone/email identifier so the stored value always matches.
  /// Egyptian mobile: +201001234567 / 00201001234567 / 1001234567 → 01001234567
  /// Email is returned unchanged.
  String _normalizeIdentifier(String id) {
    final s = id.trim();
    if (s.startsWith('+20') && s.length > 3) return '0${s.substring(3)}';
    if (s.startsWith('0020') && s.length > 4) return '0${s.substring(4)}';
    // 10-digit number typed without leading 0 (e.g. "1001234567" when +20 shown)
    if (RegExp(r'^[12]\d{9}$').hasMatch(s)) return '0$s';
    return s;
  }

  Future<void> _login() async {
    final identifier = _normalizeIdentifier(_loginIdentifier.text);
    if (identifier.isEmpty || _loginPassword.text.isEmpty) {
      _showSnack('Please enter your phone/email and password', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context
          .read<AuthProvider>()
          .login(identifier, _loginPassword.text);
      // Login succeeded — AuthProvider.notifyListeners already triggered navigation
      // No further action needed; widget will be replaced by MainShell
      return;
    } catch (e) {
      // If account not verified (403), redirect to OTP verification
      if (e is ApiException && e.statusCode == 403) {
        final body = e.body ?? {};
        _pendingUserId = body['user_id']?.toString();
        _pendingOtp = body['otp']?.toString();
        _pendingPhone = _loginIdentifier.text.trim();
        _isResetFlow = false;
        _clearOtpBoxes();
        // Auto-fill OTP boxes if server returns OTP
        if (_pendingOtp != null && _pendingOtp!.length == 4) {
          for (int i = 0; i < 4; i++) {
            _otpControllers[i].text = _pendingOtp![i];
          }
        }
        if (mounted) {
          setState(() {
            _loading = false;
            _currentScreen = _AuthScreen.otp; _otpVerified = false;
          });
          // Auto-verify after a short delay so user sees the filled boxes
          if (_pendingOtp != null && _pendingOtp!.length == 4) {
            Future.delayed(const Duration(milliseconds: 600), _verifyOtp);
          }
        }
        return;
      }
      // Make 401 "Invalid credentials" more user-friendly
      if (e is ApiException && e.statusCode == 401) {
        _showSnack('Incorrect phone/email or password. Please try again.', error: true);
      } else {
        _showSnack(e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_regName.text.trim().isEmpty) {
      _showSnack('Please enter your full name', error: true);
      return;
    }
    if (_regPhone.text.trim().isEmpty) {
      _showSnack('Please enter your phone number', error: true);
      return;
    }
    if (_regPassword.text.length < 6) {
      _showSnack('Password must be at least 6 characters', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      // Always normalize phone before sending so DB stores consistent format
      final normalizedPhone = _normalizeIdentifier(_regPhone.text.trim());
      final res = await context.read<AuthProvider>().register(
            fullName: _regName.text.trim(),
            password: _regPassword.text,
            phone: normalizedPhone,
            email: _regEmail.text.trim(),
          );
      _pendingUserId = res['user_id']?.toString();
      _pendingOtp = res['otp']?.toString();
      _pendingPhone = normalizedPhone;
      _isResetFlow = false;
      _clearOtpBoxes();
      // Auto-fill OTP boxes if server returns OTP (no SMS configured)
      if (_pendingOtp != null && _pendingOtp!.length == 4) {
        for (int i = 0; i < 4; i++) {
          _otpControllers[i].text = _pendingOtp![i];
        }
      }
      if (mounted) {
        setState(() => _currentScreen = _AuthScreen.otp);
        // Auto-verify after a short delay so user sees the filled boxes
        if (_pendingOtp != null && _pendingOtp!.length == 4) {
          Future.delayed(const Duration(milliseconds: 600), _verifyOtp);
        }
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) {
        // Account already exists — offer to login instead
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Account Already Exists',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text(
                'This phone number is already registered.\nWould you like to log in instead?',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Pre-fill login and switch tab
                    _loginIdentifier.text = _regPhone.text.trim();
                    _tabController.animateTo(0);
                    setState(
                        () => _currentScreen = _AuthScreen.welcome);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Log In',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }
      } else if (e is ApiException && e.statusCode == 400) {
        // Validation error from backend
        _showSnack('Please check your details and try again.', error: true);
      } else {
        _showSnack(e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_loading || _otpVerified) return; // prevent double-submit
    final otp = _otpValue;
    if (otp.length < 4 || _pendingUserId == null) {
      _showSnack('Please enter the complete 4-digit code', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isResetFlow) {
        // For reset flow: save OTP and move to new-password step
        _pendingOtp = otp;
        if (mounted) {
          setState(() {
            _loading = false;
            _currentScreen = _AuthScreen.newPassword;
          });
        }
        return;
      }
      // Register / login flow: verify OTP
      await context.read<AuthProvider>().verifyOtp(_pendingUserId!, otp);
      // Success — mark as verified so no further attempts are possible
      _otpVerified = true;
      // verifyOtp calls notifyListeners → AppEntryPoint rebuilds → MainShell
      // No further UI updates needed — the widget will be replaced
    } catch (e) {
      final msg = e.toString();
      // If account is already verified, redirect to login instead of looping
      if (msg.toLowerCase().contains('already verified')) {
        _showSnack('Account already verified. Please log in.', error: false);
        if (mounted) {
          setState(() {
            _loading = false;
            _currentScreen = _AuthScreen.welcome;
          });
        }
        return;
      }
      if (msg.toLowerCase().contains('invalid') || msg.toLowerCase().contains('expired')) {
        _showSnack('Incorrect code. Please check your email and try again.', error: true);
      } else {
        _showSnack(msg, error: true);
      }
    } finally {
      if (mounted && !_otpVerified) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final id = _normalizeIdentifier(_forgotIdentifierController.text);
    if (id.isEmpty) {
      _showSnack('Please enter your email or phone number', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res =
          await context.read<AuthProvider>().forgotPassword(id);
      _pendingUserId = res['user_id']?.toString();
      _pendingOtp = res['otp']?.toString();
      _isResetFlow = true;
      _clearOtpBoxes();
      setState(() => _currentScreen = _AuthScreen.resetLinkSent);
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _showSnack('No account found with this phone/email.', error: true);
      } else {
        _showSnack(e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final newPw = _newPasswordController.text;
    if (newPw.length < 6) {
      _showSnack('Password must be at least 6 characters', error: true);
      return;
    }
    if (_pendingUserId == null || _pendingOtp == null) {
      _showSnack('Session expired. Please start again.', error: true);
      setState(() => _currentScreen = _AuthScreen.forgotPassword);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().resetPassword(
            userId: _pendingUserId!,
            otp: _pendingOtp!,  // use stored OTP (verified in previous step)
            newPassword: newPw,
          );
      // AuthProvider.resetPassword calls notifyListeners → parent navigates
    } catch (e) {
      _showSnack(e.toString(), error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case _AuthScreen.register:
        return _buildRegisterScreen();
      case _AuthScreen.otp:
        return _buildOtpScreen();
      case _AuthScreen.verifySuccess:
        return _buildVerifySuccessScreen();
      case _AuthScreen.forgotPassword:
        return _buildForgotPasswordScreen();
      case _AuthScreen.resetLinkSent:
        return _buildResetLinkSentScreen();
      case _AuthScreen.newPassword:
        return _buildNewPasswordScreen();
      case _AuthScreen.welcome:
        return _buildWelcomeScreen();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WELCOME SCREEN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background photo
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1539768942893-daf53e448371?w=800&q=80',
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0A1F3D), Color(0xFF1B3A6B)],
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1F3D), Color(0xFF1B3A6B)],
                  ),
                ),
              ),
            ),
          ),

          // Dark overlay gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.40),
                    Colors.black.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.42, 0.55],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header badge ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇪🇬',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'NLE EGYPT',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Title ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trails',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ancient wonders await your journey.',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Bottom white card ──
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tab bar
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: TabBar(
                          controller: _tabController,
                          labelStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          unselectedLabelStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, fontSize: 15),
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Log In'),
                            Tab(text: 'Register'),
                          ],
                        ),
                      ),

                      // Tab views
                      SizedBox(
                        height: 292,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLoginTabContent(),
                            _buildRegisterTabContent(),
                          ],
                        ),
                      ),

                      // ── Or continue with ──
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Color(0xFFE5E7EB))),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child: Text(
                                'or continue with',
                                style: GoogleFonts.poppins(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Color(0xFFE5E7EB))),
                          ],
                        ),
                      ),

                      // Social buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
                          children: [
                            Expanded(child: _googleButton()),
                            const SizedBox(width: 12),
                            Expanded(child: _appleButton()),
                          ],
                        ),
                      ),

                      // Skip link
                      TextButton(
                        onPressed: widget.onSkip ?? widget.onBack,
                        child: Text(
                          'Just looking? Skip for now',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          _inputField(
            controller: _loginIdentifier,
            hint: 'Phone Number or Email',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _loginPassword,
            hint: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _obscureLogin,
            onToggleObscure: () =>
                setState(() => _obscureLogin = !_obscureLogin),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(
                  () => _currentScreen = _AuthScreen.forgotPassword),
              style:
                  TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _primaryButton('Continue', _login),
        ],
      ),
    );
  }

  Widget _buildRegisterTabContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _currentScreen = _AuthScreen.register),
              icon: const Icon(Icons.person_add_outlined,
                  color: Colors.white, size: 20),
              label: Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Create an account to start exploring Egypt\'s best\nrestaurants, attractions, and local gems.',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REGISTER SCREEN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRegisterScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _backButton(
                  () => setState(
                      () => _currentScreen = _AuthScreen.welcome),
                  label: 'Back'),
              const SizedBox(height: 20),

              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join thousands of travelers exploring the\nwonders of Egypt.',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              _fieldLabel('FULL NAME'),
              const SizedBox(height: 8),
              _inputField(
                  controller: _regName, hint: 'Enter your Name'),
              const SizedBox(height: 18),

              _fieldLabel('PHONE NUMBER'),
              const SizedBox(height: 8),
              _phoneField(_regPhone),
              const SizedBox(height: 18),

              _fieldLabel('EMAIL ADDRESS ( optional )'),
              const SizedBox(height: 8),
              _inputField(
                controller: _regEmail,
                hint: 'your@gmail.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),

              _fieldLabel('PASSWORD'),
              const SizedBox(height: 8),
              _inputField(
                controller: _regPassword,
                hint: 'Minimum 6 characters',
                isPassword: true,
                obscure: _obscureReg,
                onToggleObscure: () =>
                    setState(() => _obscureReg = !_obscureReg),
              ),
              const SizedBox(height: 24),

              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                        color: AppColors.textSecondary, fontSize: 12.5),
                    children: [
                      const TextSpan(
                          text: 'By clicking Register you agree to our '),
                      TextSpan(
                        text: 'Terms',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _primaryButton('Register', _register),
              const SizedBox(height: 18),

              Center(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _currentScreen = _AuthScreen.welcome),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                          color: AppColors.textPrimary, fontSize: 13.5),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log In',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  OTP SCREEN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOtpScreen() {
    final phone = _pendingPhone?.isNotEmpty == true
        ? _pendingPhone!
        : 'your phone';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    size: 30, color: AppColors.primary),
                onPressed: () => setState(() =>
                    _currentScreen = _isResetFlow
                        ? _AuthScreen.forgotPassword
                        : _AuthScreen.register),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 28),

                    Text(
                      'Verify Phone',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 4-digit code sent to',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '+20 $phone',
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_outlined,
                            size: 15, color: AppColors.primary),
                      ],
                    ),

                    // Dev mode OTP hint
                    if (_pendingOtp != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Dev OTP: $_pendingOtp',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 44),

                    // 4 OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, _buildOtpBox),
                    ),

                    const SizedBox(height: 44),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code?  ",
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: () {
                            _clearOtpBoxes();
                            if (_isResetFlow) {
                              _forgotPassword();
                            } else {
                              _resendOtp();
                            }
                          },
                          child: Text(
                            'Resend Code',
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Verify button — inside scroll so keyboard doesn't hide it
                    _loading
                        ? Column(
                            children: [
                              const CircularProgressIndicator(
                                  color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text('Verifying...',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          )
                        : _primaryButton('Verify & Continue', _verifyOtp),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendOtp() async {
    final phone = _pendingPhone;
    if (phone == null || phone.isEmpty) {
      _showSnack('Cannot resend — phone number unknown.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      Map<String, dynamic> res;
      if (_isResetFlow) {
        // Reset flow: use forgot-password which also works for verified accounts
        res = await context.read<AuthProvider>().forgotPassword(phone);
      } else {
        // Registration flow: use dedicated resend-otp endpoint
        res = await context.read<AuthProvider>().resendOtp(phone: phone);
      }
      _pendingOtp = res['otp']?.toString();
      _pendingUserId = res['user_id']?.toString();
      _showSnack('New code sent!');
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _showSnack('Phone number not found.', error: true);
      } else if (e is ApiException && e.statusCode == 400) {
        // "Account already verified" — allow to proceed to login
        _showSnack('Account already verified. Please log in.', error: false);
        setState(() => _currentScreen = _AuthScreen.welcome);
      } else {
        _showSnack('Could not resend code. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildOtpBox(int i) {
    return Container(
      width: 68,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      child: TextField(
        controller: _otpControllers[i],
        focusNode: _otpFocusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: GoogleFonts.poppins(
            fontSize: 26, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && i < 3) {
            _otpFocusNodes[i + 1].requestFocus();
          } else if (val.isEmpty && i > 0) {
            _otpFocusNodes[i - 1].requestFocus();
          }
          setState(() {});
          // Auto-submit when all 4 digits are entered
          if (_otpValue.length == 4) {
            // Close keyboard first, then verify
            FocusScope.of(context).unfocus();
            Future.delayed(const Duration(milliseconds: 300), _verifyOtp);
          }
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VERIFICATION SUCCESS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildVerifySuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Green checkmark with decorative dots
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.13),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Inner circle
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 44),
                      ),
                      // Top-right dot
                      Positioned(
                        top: 6,
                        right: 10,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Bottom-left dot
                      Positioned(
                        bottom: 10,
                        left: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),
                  Text(
                    'Verification Successful',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'your account has been verified.\nyou can now start exploring egypt\'s best\nrestaurants, attractions , and local gems.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _primaryButton('Start Exploring', () {
                // AuthProvider already has user set (via verifyOtpSilent)
                // Calling activateLogin triggers notifyListeners → navigation
                context.read<AuthProvider>().activateLogin();
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FORGOT PASSWORD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildForgotPasswordScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _backButton(
                () => setState(() => _currentScreen = _AuthScreen.welcome),
                label: 'Login',
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    // Lock icon in orange circle
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: AppColors.primary, size: 44),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Forget Password?',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'enter your email address or phone\nnumber and we will send you a link to\nreset your password.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _inputField(
                      controller: _forgotIdentifierController,
                      hint: 'Email or Phone Number',
                      prefixIcon: Icons.email_outlined,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
              child: _primaryButton('Send Reset Link', _forgotPassword),
            ),
            Center(
              child: GestureDetector(
                onTap: () {/* TODO: contact support screen */},
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Have trouble?  '),
                      TextSpan(
                        text: 'Contact Support',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RESET LINK SENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildResetLinkSentScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _backButton(
                () => setState(() => _currentScreen = _AuthScreen.welcome),
                label: 'Login',
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Envelope with decorative dots
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_rounded,
                            color: AppColors.primary, size: 38),
                      ),
                      Positioned(
                        top: 8,
                        right: 14,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Reset Link Sent',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: Text(
                      'We have sent a 4-digit verification code to\nyour phone number or email. Enter it\nbelow to reset your password.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Column(
                children: [
                  if (_pendingOtp != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Dev OTP: $_pendingOtp',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  _primaryButton(
                    'Enter Verification Code',
                    () {
                      _clearOtpBoxes();
                      setState(() => _currentScreen = _AuthScreen.otp);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code?  ",
                        style: GoogleFonts.poppins(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: _forgotPassword,
                        child: Text(
                          'Resend',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NEW PASSWORD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNewPasswordScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    size: 30, color: AppColors.primary),
                onPressed: () =>
                    setState(() => _currentScreen = _AuthScreen.otp),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.primary, size: 44),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Create New Password',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your new password must be different\nfrom previously used passwords.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _fieldLabel('NEW PASSWORD'),
                    const SizedBox(height: 8),
                    _inputField(
                      controller: _newPasswordController,
                      hint: 'Minimum 6 characters',
                      isPassword: true,
                      obscure: _obscureReg,
                      onToggleObscure: () =>
                          setState(() => _obscureReg = !_obscureReg),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: _primaryButton('Reset Password', _resetPassword),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _backButton(VoidCallback onTap, {String label = 'Back'}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.chevron_left_rounded,
          color: AppColors.primary, size: 22),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
    );
  }

  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFB0B7C3), fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: const Color(0xFFB0B7C3), size: 20)
            : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFFB0B7C3),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _phoneField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text('🇪🇬', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '+20',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                    width: 1.5, height: 24, color: const Color(0xFFDDE0E7)),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '100 123 4567',
                hintStyle: GoogleFonts.poppins(
                    color: const Color(0xFFB0B7C3), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().loginWithGoogle();
      // Success: AuthProvider notifies → MainShell replaces this screen
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.isNotEmpty && msg != 'Google Sign-In was cancelled.') {
        _showSnack(msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _googleButton() {
    return OutlinedButton(
      onPressed: _loading ? null : _loginWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GoogleLogoPainter())),
          const SizedBox(width: 8),
          Text('Google', style: GoogleFonts.poppins(
              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _appleButton() {
    return OutlinedButton(
      onPressed: () {
        _showSnack('Apple Sign-In coming soon!');
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: const Icon(Icons.apple, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Apple', style: GoogleFonts.poppins(
              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Google G Logo (multicolor CustomPainter) ──────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final strokeW = size.width * 0.18;
    final half = strokeW / 2;

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.butt;

    // Blue arc (top-right → bottom-right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - half),
        -0.52, 2.09, false, paint);

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - half),
        -2.62, 2.10, false, paint);

    // Yellow arc (bottom-left)
    paint.color = const Color(0xFFFBBC04);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - half),
        2.09, 0.785, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - half),
        2.88, 0.79, false, paint);

    // White inner circle (cuts the middle)
    canvas.drawCircle(Offset(cx, cy), r * 0.55,
        Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Blue crossbar (horizontal bar of the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(cx - 0.05, cy - size.height * 0.11,
        r - half * 0.4, size.height * 0.22), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
