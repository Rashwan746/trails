import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/place_model.dart';
import '../providers/map_state_provider.dart';
import '../services/places_service.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/analytics_service.dart';
import 'overview_screen.dart';

class MapScreen extends StatefulWidget {
  final Place? focusPlace;
  const MapScreen({super.key, this.focusPlace});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController      _mapController  = MapController();
  final _placesService   = PlacesService();
  final _favoritesService = FavoritesService();
  final _locationService  = LocationService();
  final _analytics        = AnalyticsService();
  final _searchCtrl       = TextEditingController();
  final _searchFocus      = FocusNode();

  List<Place> _allPlaces      = [];
  List<Place> _filteredPlaces = [];
  Place?      _selectedPlace;
  bool        _loading        = true;
  bool        _searchActive   = false;
  String?     _selectedCategory;
  LatLng?     _userLocation;
  bool        _isFav          = false;

  // top-bar slide-up when a place is selected
  late AnimationController _barAnimCtrl;
  late Animation<Offset>   _barSlide;

  // bottom card slide-up
  late AnimationController _cardAnimCtrl;
  late Animation<Offset>   _cardSlide;

  static const _cairoCenter = LatLng(30.0444, 31.2357);

  // glass dark colour shared by top bar + bottom card
  static const _glassBg = Color(0xCC000000); // ~80 % black

  static const _categories = [
    ('All',         null,         Icons.public_rounded,          Color(0xFFE8750A)),
    ('Attractions', 'historical', Icons.account_balance_rounded, Color(0xFF8B5E3C)),
    ('Dining',      'restaurant', Icons.restaurant_rounded,      Color(0xFFE11D48)),
    ('Hotels',      'hotel',      Icons.bed_rounded,             Color(0xFF0D9488)),
    ('Nature',      'nature',     Icons.forest_rounded,          Color(0xFF16A34A)),
    ('Beaches',     'beach',      Icons.beach_access_rounded,    Color(0xFF0891B2)),
    ('Desert',      'desert',     Icons.wb_sunny_rounded,        Color(0xFFD97706)),
    ('Museums',     'museum',     Icons.museum_rounded,          Color(0xFF7C3AED)),
    ('Religious',   'religious',  Icons.mosque_rounded,          Color(0xFF059669)),
    ('Shops',       'market',     Icons.storefront_rounded,      Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _analytics.screenView('map');

    _barAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _barSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.5))
        .animate(CurvedAnimation(parent: _barAnimCtrl, curve: Curves.easeInCubic));

    _cardAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOutCubic));

    _searchCtrl.addListener(_onSearch);
    _loadUserLocation();
    _loadPlaces();
  }

  @override
  void dispose() {
    _barAnimCtrl.dispose();
    _cardAnimCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredPlaces = q.isEmpty
          ? List.from(_allPlaces)
          : _allPlaces.where((p) => p.getName('en').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _loadUserLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    try {
      final res = await _placesService.getPlaces(category: _selectedCategory, limit: 50);
      if (!mounted) return;
      final places = res['places'] as List<Place>;
      setState(() { _allPlaces = places; _filteredPlaces = List.from(places); _loading = false; });
      if (widget.focusPlace != null) {
        Future.delayed(const Duration(milliseconds: 300), () => _animateToPlace(widget.focusPlace!));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _animateToPlace(Place place) {
    _mapController.move(LatLng(place.location.latitude, place.location.longitude), 13.0);
    _selectPlace(place);
  }

  Future<void> _selectPlace(Place place) async {
    _searchFocus.unfocus();
    setState(() { _selectedPlace = place; _searchActive = false; _isFav = false; });
    // hide top bar + bottom nav, show card
    _barAnimCtrl.forward();
    _cardAnimCtrl.forward(from: 0);
    context.read<MapStateProvider>().selectPlace();
    // check favourite
    try {
      final fav = await _favoritesService.isFavorite(place.id.toString());
      if (mounted) setState(() => _isFav = fav);
    } catch (_) {}
  }

  void _deselectPlace() {
    _cardAnimCtrl.reverse().then((_) {
      if (mounted) setState(() => _selectedPlace = null);
    });
    _barAnimCtrl.reverse();
    context.read<MapStateProvider>().deselectPlace(); // bring nav bar back
  }

  void _goToMyLocation() {
    if (_userLocation != null) _mapController.move(_userLocation!, 14.0);
  }

  Future<void> _toggleFav() async {
    if (_selectedPlace == null) return;
    try {
      final nowFav = await _favoritesService.toggleFavorite(_selectedPlace!.id.toString());
      if (mounted) setState(() => _isFav = nowFav);
      _showSnack(nowFav ? 'Added to favourites ❤️' : 'Removed from favourites');
    } catch (_) {
      _showSnack('Sign in to save places');
    }
  }

  void _sharePlace() {
    if (_selectedPlace == null) return;
    final name = _selectedPlace!.getName('en');
    final url  = 'http://localhost:8081';
    final text = '$name — Discover Egypt\n$url';
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Link copied to clipboard 🔗');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k == k.truncate() ? 0 : 1)}k';
    }
    return count.toString();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'historical': return 'Historical Landmark';
      case 'beach':      return 'Beach';
      case 'desert':     return 'Desert';
      case 'museum':     return 'Museum';
      case 'religious':  return 'Religious Site';
      case 'nature':     return 'Nature';
      case 'market':     return 'Market & Shops';
      case 'cruise':     return 'Nile Cruise';
      case 'restaurant': return 'Dining';
      case 'hotel':      return 'Hotel';
      default:           return 'Attraction';
    }
  }

  Color _categoryColor(String cat) {
    for (final c in _categories) { if (c.$2 == cat) return c.$4; }
    return AppColors.primary;
  }

  // shared glass decoration for top bar + bottom card
  BoxDecoration _glassDeco({BorderRadius? radius, Border? border}) => BoxDecoration(
    color: Colors.black.withOpacity(0.52),
    borderRadius: radius,
    border: border,
  );

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { _searchFocus.unfocus(); setState(() => _searchActive = false); },
        child: Stack(
          children: [

            // ── Map ──────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.focusPlace != null
                    ? LatLng(widget.focusPlace!.location.latitude, widget.focusPlace!.location.longitude)
                    : _cairoCenter,
                initialZoom: widget.focusPlace != null ? 13.0 : 10.5,
                onTap: (_, __) {
                  if (_selectedPlace != null) { _deselectPlace(); return; }
                  _searchFocus.unfocus();
                  setState(() => _searchActive = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.discover.egypt',
                  maxZoom: 19,
                ),
                if (_userLocation != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _userLocation!, width: 24, height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90D9), shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: const Color(0xFF4A90D9).withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                        ),
                      ),
                    ),
                  ]),
                MarkerLayer(
                  markers: _filteredPlaces.map((place) {
                    final isSel  = _selectedPlace?.id == place.id;
                    final color  = _categoryColor(place.category);
                    return Marker(
                      point: LatLng(place.location.latitude, place.location.longitude),
                      width: 130, height: isSel ? 70 : 38,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _selectPlace(place),
                        child: _MapPin(label: place.getName('en'), isSelected: isSel, color: color),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // ── Top bar (slides up when place selected) ───────────────
            Positioned(
              top: topPad + 12, left: 14, right: 14,
              child: SlideTransition(
                position: _barSlide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Search bar ──────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: _glassDeco(
                            radius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  focusNode:  _searchFocus,
                                  onTap: () => setState(() => _searchActive = true),
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    hintText: 'Search places...',
                                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w400),
                                    border: InputBorder.none, isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              if (_searchCtrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () { _searchCtrl.clear(); setState(() => _filteredPlaces = List.from(_allPlaces)); },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                                  ),
                                )
                              else
                                const SizedBox(width: 14),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Search results dropdown ──────────────────────
                    if (_searchActive && _searchCtrl.text.isNotEmpty && _filteredPlaces.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: _glassDeco(
                              radius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: _filteredPlaces.length.clamp(0, 6),
                              separatorBuilder: (_, __) => Divider(color: Colors.white12, height: 1),
                              itemBuilder: (_, i) {
                                final p = _filteredPlaces[i];
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      color: _categoryColor(p.category).withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.place_rounded, color: _categoryColor(p.category), size: 18),
                                  ),
                                  title: Text(p.getName('en'),
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                  subtitle: Text(p.governorate,
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54)),
                                  onTap: () { _searchCtrl.clear(); _animateToPlace(p); },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // ── Category chips ──────────────────────────────
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final (label, id, icon, color) = _categories[i];
                          final isSel = _selectedCategory == id;
                          return GestureDetector(
                            onTap: () { setState(() => _selectedCategory = id); _loadPlaces(); },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 13),
                                    decoration: BoxDecoration(
                                      color: isSel ? color.withOpacity(0.80) : Colors.black.withOpacity(0.48),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSel ? color.withOpacity(0.5) : Colors.white.withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 13, color: Colors.white),
                                        const SizedBox(width: 5),
                                        Text(label.toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5, fontWeight: FontWeight.w700,
                                            color: Colors.white, letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Loading pill ──────────────────────────────────────────
            if (_loading)
              Positioned(
                top: topPad + 160, left: 0, right: 0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        decoration: _glassDeco(
                          radius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.85))),
                            const SizedBox(width: 10),
                            Text('Loading places...', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── My-location FAB ───────────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              right: 14,
              bottom: _selectedPlace != null ? 290 : 90,
              child: GestureDetector(
                onTap: _goToMyLocation,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
                      ),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 21),
                    ),
                  ),
                ),
              ),
            ),

            // ── Place bottom card ─────────────────────────────────────
            if (_selectedPlace != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SlideTransition(
                  position: _cardSlide,
                  child: _PlaceGlassCard(
                    place:         _selectedPlace!,
                    isFav:         _isFav,
                    formatCount:   _formatCount,
                    categoryLabel: _categoryLabel,
                    categoryColor: _categoryColor,
                    glassDeco:     _glassDeco,
                    onViewDetails: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => OverviewScreen(place: _selectedPlace!))),
                    onClose:       _deselectPlace,
                    onFav:         _toggleFav,
                    onShare:       _sharePlace,
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// ─── Map pin ──────────────────────────────────────────────────────────────────
class _MapPin extends StatelessWidget {
  final String label;
  final bool   isSelected;
  final Color  color;
  const _MapPin({required this.label, required this.isSelected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.90),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Text(label,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
        ],
        Container(
          width: isSelected ? 38 : 28, height: isSelected ? 38 : 28,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.white : color, width: 2.5),
            boxShadow: [BoxShadow(
              color: color.withOpacity(isSelected ? 0.55 : 0.3),
              blurRadius: isSelected ? 16 : 8,
              spreadRadius: isSelected ? 2 : 0,
            )],
          ),
          child: Center(
            child: Icon(Icons.place_rounded,
              size: isSelected ? 20 : 14,
              color: isSelected ? Colors.white : color),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom glass card ────────────────────────────────────────────────────────
class _PlaceGlassCard extends StatelessWidget {
  final Place      place;
  final bool       isFav;
  final String Function(int)    formatCount;
  final String Function(String) categoryLabel;
  final Color  Function(String) categoryColor;
  final BoxDecoration Function({BorderRadius? radius, Border? border}) glassDeco;
  final VoidCallback onViewDetails;
  final VoidCallback onClose;
  final VoidCallback onFav;
  final VoidCallback onShare;

  const _PlaceGlassCard({
    required this.place,       required this.isFav,
    required this.formatCount, required this.categoryLabel,
    required this.categoryColor, required this.glassDeco,
    required this.onViewDetails, required this.onClose,
    required this.onFav,       required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final catColor  = categoryColor(place.category);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: glassDeco(
            radius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              const SizedBox(height: 10),
              Container(width: 38, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(height: 16),

              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPad + 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Left info ─────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.getName('en'),
                            style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: Colors.white, height: 1.2,
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          Row(children: [
                            const Icon(Icons.star_rounded, color: AppColors.starColor, size: 15),
                            const SizedBox(width: 3),
                            Text(place.avgRating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(width: 4),
                            Text('(${formatCount(place.reviewCount)} reviews)',
                              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white60)),
                            const SizedBox(width: 6),
                            Container(width: 3, height: 3,
                              decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(categoryLabel(place.category),
                              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white60),
                              overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 14),

                          // Get Directions button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: onViewDetails,
                              icon: const Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
                              label: Text('Get Directions',
                                style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Save + Share chips
                          Row(children: [
                            _GlassChip(
                              icon: isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              label: isFav ? 'Saved' : 'Save',
                              active: isFav,
                              activeColor: AppColors.primary,
                              onTap: onFav,
                            ),
                            const SizedBox(width: 10),
                            _GlassChip(
                              icon: Icons.share_rounded,
                              label: 'Share',
                              onTap: onShare,
                            ),
                          ]),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ── Right: image + close ──────────────────────
                    Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: place.displayImage.isNotEmpty
                                  ? Image.network(place.displayImage,
                                      width: 100, height: 100, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _imgFallback(catColor))
                                  : _imgFallback(catColor),
                            ),
                            // close ×
                            Positioned(
                              top: 5, right: 5,
                              child: GestureDetector(
                                onTap: onClose,
                                child: ClipOval(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // category badge
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 100, height: 30,
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: catColor.withOpacity(0.45), width: 1),
                              ),
                              child: Center(
                                child: Text(categoryLabel(place.category),
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                  overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback(Color c) => Container(
    width: 100, height: 100,
    decoration: BoxDecoration(color: c.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
    child: Icon(Icons.photo_rounded, color: c, size: 36),
  );
}

// ─── Glass chip ───────────────────────────────────────────────────────────────
class _GlassChip extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final bool      active;
  final Color?    activeColor;
  final VoidCallback onTap;

  const _GlassChip({
    required this.icon, required this.label, required this.onTap,
    this.active = false, this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final col = active && activeColor != null ? activeColor! : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? activeColor!.withOpacity(0.18)
                  : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? activeColor!.withOpacity(0.45) : Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: col),
                const SizedBox(width: 5),
                Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: col)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
