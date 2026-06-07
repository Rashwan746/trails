import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Per-page animation controller (resets on page change)
  late AnimationController _entryCtrl;

  // Entry animations
  late Animation<double> _imgScale;
  late Animation<double> _cardSlide;
  late Animation<double> _badgeFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _descFade;
  late Animation<Offset> _descSlide;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;

  static const _pages = [
    _PageData(
      assetPath: 'assets/images/onboarding_gem.jpg',
      imageAlignment: Alignment.bottomCenter,
      location: 'GEM, EGYPT',
      titleLine1: 'Explore Ancient',
      titleLine2: 'Wonders',
      description:
          "Your personal guide to Egypt's best hotels,\nrestaurants, and historical sites.",
      buttonLabel: 'Get Started',
    ),
    _PageData(
      assetPath: 'assets/images/onboarding_aswan.webp',
      location: 'ASWAN, EGYPT',
      titleLine1: 'Discover Nearby',
      titleLine2: 'Places',
      description:
          'Find attractions, restaurants, and services\naround you based on your location.',
      buttonLabel: 'Continue',
    ),
    _PageData(
      assetPath: 'assets/images/onboarding_nile.jpg',
      location: 'NILE, EGYPT',
      titleLine1: 'Enjoy Egypt Like',
      titleLine2: 'a Local',
      description:
          'Explore Egypt smarter with verified places,\nreal reviews, and simple navigation.',
      buttonLabel: 'Start Exploring →',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _buildAnimations();
    _entryCtrl.forward();
  }

  void _buildAnimations() {
    // Image subtle zoom (Ken Burns)
    _imgScale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
    );
    // Card slides up from slight offset
    _cardSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)),
    );
    // Location badge
    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.1, 0.45, curve: Curves.easeIn)),
    );
    // Title
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.25, 0.6, curve: Curves.easeIn)),
    );
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic)));
    // Description
    _descFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.4, 0.72, curve: Curves.easeIn)),
    );
    _descSlide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.4, 0.75, curve: Curves.easeOutCubic)));
    // Button
    _btnFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.55, 0.88, curve: Curves.easeIn)),
    );
    _btnSlide = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic)));
  }

  void _resetAnimation() {
    _entryCtrl.reset();
    _entryCtrl.forward();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic);
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen PageView ────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _resetAnimation();
            },
            itemBuilder: (_, i) => _buildPage(_pages[i]),
          ),

          // ── Top bar: location badge + Skip ──────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Location badge (animated)
                  AnimatedBuilder(
                    animation: _entryCtrl,
                    builder: (_, __) => FadeTransition(
                      opacity: _badgeFade,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppColors.primary, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  _pages[_currentPage].location,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Skip button
                  GestureDetector(
                    onTap: widget.onDone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_PageData page) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background photo with Ken Burns zoom ─────────────────────────
        AnimatedBuilder(
          animation: _imgScale,
          builder: (_, __) => Transform.scale(
            scale: _imgScale.value,
            child: page.assetPath != null
                ? Image.asset(
                    page.assetPath!,
                    fit: BoxFit.cover,
                    alignment: page.imageAlignment,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFF0D1B2A)),
                  )
                : Container(color: const Color(0xFF0D1B2A)),
          ),
        ),

        // ── Gradient overlay ─────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 0.65, 1.0],
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),

        // ── Bottom content card (animated slide up) ───────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _cardSlide,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _cardSlide.value),
              child: child,
            ),
            child: _buildCard(page),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_PageData page) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(28, 28, 28, bottomPad + 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Page indicator
          SmoothPageIndicator(
            controller: _pageCtrl,
            count: _pages.length,
            effect: ExpandingDotsEffect(
              dotHeight: 8,
              dotWidth: 8,
              expansionFactor: 3.5,
              spacing: 6,
              activeDotColor: AppColors.primary,
              dotColor: const Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(height: 22),

          // Title (animated)
          AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, __) => FadeTransition(
              opacity: _titleFade,
              child: SlideTransition(
                position: _titleSlide,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(text: page.titleLine1),
                      const TextSpan(text: '\n'),
                      TextSpan(
                        text: page.titleLine2,
                        style:
                            const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Description (animated)
          AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, __) => FadeTransition(
              opacity: _descFade,
              child: SlideTransition(
                position: _descSlide,
                child: Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Button (animated)
          AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, __) => FadeTransition(
              opacity: _btnFade,
              child: SlideTransition(
                position: _btnSlide,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: Text(
                      page.buttonLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final String imageUrl;
  final String? assetPath;
  final Alignment imageAlignment;
  final String location;
  final String titleLine1;
  final String titleLine2;
  final String description;
  final String buttonLabel;

  const _PageData({
    this.imageUrl = '',
    this.assetPath,
    this.imageAlignment = Alignment.center,
    required this.location,
    required this.titleLine1,
    required this.titleLine2,
    required this.description,
    required this.buttonLabel,
  });
}
