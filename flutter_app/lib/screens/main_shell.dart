import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/map_state_provider.dart';
import '../utils/page_transitions.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // AI button pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<Widget> _screens = const [
    HomeScreen(),
    FavoritesScreen(),
    MapScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final mapPlaceSelected = context.watch<MapStateProvider>().placeSelected;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        offset: mapPlaceSelected ? const Offset(0, 1.5) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: mapPlaceSelected ? 0.0 : 1.0,
          child: _buildNavBar(l10n, bottomPadding),
        ),
      ),
    );
  }

  Widget _buildNavBar(AppLocalizations l10n, double bottomPadding) {
    final items = [
      _NavItem(icon: Icons.explore_rounded,  label: 'Discover'),
      _NavItem(icon: Icons.favorite_rounded, label: l10n.favorites),
      _NavItem(icon: Icons.map_rounded,      label: l10n.map),
      _NavItem(icon: Icons.person_rounded,   label: l10n.profile),
    ];

    final leftItems  = items.sublist(0, 2);
    final rightItems = items.sublist(2, 4);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, 0, 16,
          bottomPadding > 0 ? bottomPadding : 12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ── Dark glass pill bar ────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E).withOpacity(0.78),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Left 2 items
                    ...leftItems.asMap().entries.map((e) =>
                        Expanded(child: _navItem(items[e.key], e.key))),

                    // Centre gap
                    const SizedBox(width: 68),

                    // Right 2 items
                    ...rightItems.asMap().entries.map((e) =>
                        Expanded(child: _navItem(items[e.key + 2], e.key + 2))),
                  ],
                ),
              ),
            ),
          ),

          // ── AI glow behind the button ──────────────────────────────────
          Positioned(
            top: -8,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.22),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // ── AI floating button ─────────────────────────────────────────
          Positioned(
            top: -26,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                slideUpRoute(const ChatScreen()),
              ),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) =>
                    Transform.scale(scale: _pulseAnim.value, child: child),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.45),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: _AiIcon(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(_NavItem item, int index) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.40),
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.40),
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}

// Custom AI icon widget (two-letter "AI" styled)
class _AiIcon extends StatelessWidget {
  const _AiIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer sparkle ring
        Icon(Icons.auto_awesome_rounded,
            color: Colors.white.withOpacity(0.25), size: 42),
        // AI text
        Text('AI',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            )),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
