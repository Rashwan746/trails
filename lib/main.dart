import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';

import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize analytics
  AnalyticsService().init();
  AnalyticsService().track(AnalyticsEvent.appOpen);

  runApp(const DiscoverEgyptApp());
}

class DiscoverEgyptApp extends StatelessWidget {
  const DiscoverEgyptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'Discover Egypt',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
                secondary: AppColors.secondary,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(),
              scaffoldBackgroundColor: AppColors.background,
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: const IconThemeData(color: AppColors.textPrimary),
                titleTextStyle: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            home: const AppEntryPoint(),
          );
        },
      ),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _initialized = false;
  bool _onboardingDone = false;
  bool _showAuth = false;
  bool _guestMode = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.tryAutoLogin();
    await Future.delayed(const Duration(milliseconds: 1500)); // splash
    setState(() {
      _initialized = true;
      // If already logged in, skip onboarding and go directly home
      if (authProvider.isLoggedIn) {
        _onboardingDone = true;
        _wasLoggedIn = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Detect logout: user was logged in but now isn't → go to auth screen
    if (_wasLoggedIn && !auth.isLoggedIn) {
      _wasLoggedIn = false;
      _guestMode = false;
      _onboardingDone = true;
      _showAuth = true;
    }
    if (auth.isLoggedIn) _wasLoggedIn = true;

    // Determine the current screen widget
    Widget screen;
    if (!_initialized) {
      screen = const SplashScreen();
    } else if (!_onboardingDone) {
      screen = OnboardingScreen(
        key: const ValueKey('onboarding'),
        onDone: () => setState(() {
          _onboardingDone = true;
          _showAuth = true;
        }),
      );
    } else if (auth.isLoggedIn || _guestMode) {
      screen = const MainShell(key: ValueKey('shell'));
    } else if (_showAuth) {
      screen = AuthScreen(
        key: const ValueKey('auth'),
        onBack: () => setState(() => _showAuth = false),
        onSkip: () => setState(() => _guestMode = true),
      );
    } else {
      screen = OnboardingScreen(
        key: const ValueKey('onboarding2'),
        onDone: () => setState(() => _showAuth = true),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: screen,
    );
  }
}
