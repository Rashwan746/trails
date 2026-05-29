import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/place_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../services/analytics_service.dart';
import '../widgets/place_card.dart';
import '../widgets/offline_banner.dart';
import 'overview_screen.dart';
import 'search_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import '../utils/page_transitions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _analytics = AnalyticsService();

  List<Place> _featured = [];
  List<Place> _nearby = [];
  List<Place> _restaurants = [];
  List<Place> _hotels = [];
  bool _loading = true;
  String? _error;

  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _analytics.screenView('home');
    _load();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      final results = await Future.wait([
        _placesService.getFeatured(),
        _placesService.getNearby(
          lat: position?.latitude,
          lng: position?.longitude,
        ),
        _placesService.getPlaces(category: 'restaurant', limit: 20),
        _placesService.getPlaces(category: 'hotel', limit: 20),
      ]);
      if (mounted) {
        setState(() {
          _featured = results[0] as List<Place>;
          _nearby = results[1] as List<Place>;
          _restaurants = (results[2] as Map)['places'] as List<Place>;
          _hotels = (results[3] as Map)['places'] as List<Place>;
          _loading = false;
        });
        // Wait for frame to build then start stagger
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _staggerCtrl.forward(from: 0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;
    final isAr = context.watch<LocaleProvider>().isArabic;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(user?.fullName ?? 'Traveler', isAr),
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(child: _buildError())
                  else ...[
                    // ── Category Browser ──────────────────────────────
                    _buildCategoryBrowser(),
                    // ── Featured ──────────────────────────────────────
                    _buildSectionHeader('✨ Top Picks', seeAllLabel: l10n.seeAll, onSeeAll: () {
                      Navigator.push(context, slideRightRoute(const SearchScreen()));
                    }),
                    _buildFeaturedList(isAr),
                    // ── Restaurants ───────────────────────────────────
                    if (_restaurants.isNotEmpty) ...[
                      _buildSectionHeader('🍽️ Restaurants', seeAllLabel: 'See All', onSeeAll: () {
                        Navigator.push(context, slideRightRoute(const SearchScreen(initialCategory: 'restaurant')));
                      }),
                      _buildHorizontalList(_restaurants, isAr),
                    ],
                    // ── Hotels ────────────────────────────────────────
                    if (_hotels.isNotEmpty) ...[
                      _buildSectionHeader('🏨 Hotels', seeAllLabel: 'See All', onSeeAll: () {
                        Navigator.push(context, slideRightRoute(const SearchScreen(initialCategory: 'hotel')));
                      }),
                      _buildHorizontalList(_hotels, isAr),
                    ],
                    // ── Nearby ────────────────────────────────────────
                    _buildSectionHeader('🗺️ Nearby Gems', seeAllLabel: 'More', onSeeAll: () {
                      Navigator.push(context, slideRightRoute(const SearchScreen()));
                    }),
                    _buildNearbyList(isAr),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 60, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'Could not load places',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text('Retry',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(String name, bool isAr) {
    return SliverAppBar(
      expandedHeight: 250,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: const [],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background photo
            Image.network(
              'https://images.unsplash.com/photo-1568322445389-f64ac2515020?w=900&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),

            // 2. Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
              ),
            ),

            // 3. Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location row + profile icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context, slideUpRoute(const MapScreen())),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Cairo',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context, slideUpRoute(const ProfileScreen())),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Heading
                    Text(
                      'Hey, Traveler! Tell us',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'where you want to go',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Search bar
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          slideRightRoute(const SearchScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: Colors.white60, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Search places',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'temples, food, or hotels....',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.tune_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ), // ClipRRect
        // Collapsed title
        title: Text(
          'Discover Egypt',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  Widget _buildSectionHeader(String title,
      {VoidCallback? onSeeAll, String? seeAllLabel}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  seeAllLabel ?? 'See All',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedList(bool isAr) {
    if (_featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 280,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          scrollDirection: Axis.horizontal,
          itemCount: _featured.length,
          itemBuilder: (_, i) => _staggerItem(
            index: i,
            horizontal: true,
            child: FeaturedPlaceCard(
              place: _featured[i],
              locale: isAr ? 'ar' : 'en',
              onTap: () => _openPlace(_featured[i]),
              onFavTap: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyList(bool isAr) {
    if (_nearby.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _staggerItem(
            index: i,
            horizontal: false,
            child: NearbyPlaceCard(
              place: _nearby[i],
              locale: isAr ? 'ar' : 'en',
              onTap: () => _openPlace(_nearby[i]),
            ),
          ),
          childCount: _nearby.length,
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<Place> places, bool isAr) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 260,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          scrollDirection: Axis.horizontal,
          itemCount: places.length,
          itemBuilder: (_, i) => FeaturedPlaceCard(
            place: places[i],
            locale: isAr ? 'ar' : 'en',
            onTap: () => _openPlace(places[i]),
            onFavTap: () => setState(() {}),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBrowser() {
    final cats = [
      ('Historical', 'historical', '🏛️', const Color(0xFFE8750A)),
      ('Beach', 'beach', '🏖️', const Color(0xFF0891B2)),
      ('Desert', 'desert', '🏜️', const Color(0xFFF4A261)),
      ('Museum', 'museum', '🏺', const Color(0xFF7C3AED)),
      ('Religious', 'religious', '🕌', const Color(0xFF059669)),
      ('Nature', 'nature', '🌿', const Color(0xFF16A34A)),
      ('Market', 'market', '🛍️', const Color(0xFFDC2626)),
      ('Cruise', 'cruise', '🚢', const Color(0xFF2563EB)),
      ('Restaurants', 'restaurant', '🍽️', const Color(0xFFE11D48)),
      ('Hotels', 'hotel', '🏨', const Color(0xFF0D9488)),
    ];
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              '🌍 Browse Categories',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final (label, id, emoji, color) = cats[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      slideRightRoute(SearchScreen(initialCategory: id))),
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Staggered fade+slide animation for list items
  Widget _staggerItem({
    required int index,
    required bool horizontal,
    required Widget child,
  }) {
    final delay = (index * 0.1).clamp(0.0, 0.7);
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(delay, end, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(
      begin: horizontal ? const Offset(0.15, 0) : const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(delay, end, curve: Curves.easeOutCubic),
      ),
    );
    return AnimatedBuilder(
      animation: _staggerCtrl,
      builder: (_, __) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }

  void _openPlace(Place place) {
    Navigator.push(context, slideUpRoute(OverviewScreen(place: place)));
  }
}
