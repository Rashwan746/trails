import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../models/place_model.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../services/analytics_service.dart';
import 'overview_screen.dart';

class MapScreen extends StatefulWidget {
  final Place? focusPlace;
  const MapScreen({super.key, this.focusPlace});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _placesService = PlacesService();
  final _locationService = LocationService();
  final _analytics = AnalyticsService();

  List<Place> _places = [];
  Place? _selectedPlace;
  bool _loading = true;
  String? _selectedCategory;
  LatLng? _userLocation;

  static const _egyptCenter = LatLng(26.8206, 30.8025);
  static const _defaultZoom = 6.0;

  @override
  void initState() {
    super.initState();
    _analytics.screenView('map');
    _loadUserLocation();
    _loadPlaces();
  }

  Future<void> _loadUserLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() =>
          _userLocation = LatLng(position.latitude, position.longitude));
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final res = await _placesService.getPlaces(
        category: _selectedCategory,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _places = res['places'];
          _loading = false;
        });
      }
      if (widget.focusPlace != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _animateToPlace(widget.focusPlace!);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _animateToPlace(Place place) {
    _mapController.move(
      LatLng(place.location.latitude, place.location.longitude),
      13.0,
    );
    setState(() => _selectedPlace = place);
  }

  void _goToMyLocation() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 13.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get your location.')),
      );
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'historical': return const Color(0xFFFF6B35);
      case 'beach': return const Color(0xFF00B4D8);
      case 'desert': return const Color(0xFFF4A261);
      case 'museum': return const Color(0xFF9B59B6);
      case 'religious': return const Color(0xFF27AE60);
      case 'nature': return const Color(0xFF2ECC71);
      case 'market': return const Color(0xFFE74C3C);
      case 'cruise':      return const Color(0xFF3498DB);
      case 'restaurant':  return const Color(0xFFE11D48);
      case 'hotel':       return const Color(0xFF0D9488);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.focusPlace != null
                  ? LatLng(widget.focusPlace!.location.latitude,
                      widget.focusPlace!.location.longitude)
                  : _egyptCenter,
              initialZoom: widget.focusPlace != null ? 13.0 : _defaultZoom,
              onTap: (_, __) => setState(() => _selectedPlace = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.discover.egypt',
                maxZoom: 20,
                fallbackUrl:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileBuilder: (context, tileWidget, tile) => tileWidget,
              ),
              // User location marker
              if (_userLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _userLocation!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                  ),
                ]),
              // Place markers
              MarkerLayer(
                markers: _places.map((place) {
                  final isSelected = _selectedPlace?.id == place.id;
                  final color = _categoryColor(place.category);
                  return Marker(
                    point: LatLng(
                        place.location.latitude, place.location.longitude),
                    width: isSelected ? 44 : 36,
                    height: isSelected ? 44 : 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlace = place),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: isSelected ? 14 : 8,
                              spreadRadius: isSelected ? 2 : 0,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _categoryEmoji(place.category),
                            style: TextStyle(
                                fontSize: isSelected ? 18 : 14),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Search bar / top bar ─────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Explore Egypt',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (Navigator.canPop(context))
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Category filter ──────────────────────────────────────
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: _buildCategoryFilter(),
          ),

          // ── Loading ──────────────────────────────────────────────
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),

          // ── Selected place card ──────────────────────────────────
          if (_selectedPlace != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _PlaceMapCard(
                place: _selectedPlace!,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            OverviewScreen(place: _selectedPlace!))),
                onClose: () => setState(() => _selectedPlace = null),
              ),
            ),

          // ── Floating buttons ─────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedPlace != null ? 200 : 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'myLocation',
                  onPressed: _goToMyLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'egyptView',
                  onPressed: () =>
                      _mapController.move(_egyptCenter, _defaultZoom),
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.public_rounded,
                      color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'historical': return '🏛️';
      case 'beach': return '🏖️';
      case 'desert': return '🏜️';
      case 'museum': return '🏺';
      case 'religious': return '🕌';
      case 'nature': return '🌿';
      case 'market': return '🛍️';
      case 'cruise':     return '🚢';
      case 'restaurant': return '🍽️';
      case 'hotel':      return '🏨';
      default: return '📍';
    }
  }

  Widget _buildCategoryFilter() {
    final cats = [
      ('All', null, '🌍'),
      ('Historical', 'historical', '🏛️'),
      ('Beach', 'beach', '🏖️'),
      ('Desert', 'desert', '🏜️'),
      ('Museum', 'museum', '🏺'),
      ('Religious', 'religious', '🕌'),
      ('Nature', 'nature', '🌿'),
      ('Market', 'market', '🛍️'),
      ('Restaurants', 'restaurant', '🍽️'),
      ('Hotels', 'hotel', '🏨'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final (label, id, emoji) = cats[i];
          final isSelected = _selectedCategory == id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = id);
              _loadPlaces();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1), blurRadius: 8)
                ],
              ),
              child: Text(
                '$emoji $label',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PlaceMapCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _PlaceMapCard(
      {required this.place, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: place.displayImage.isNotEmpty
                    ? Image.network(
                        place.displayImage,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.secondary,
                          child: const Icon(Icons.image,
                              color: Colors.white30),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.getName('en'),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place.governorate,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.starColor, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          place.avgRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textLight, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.explore_rounded,
                      color: Colors.white, size: 16),
                  label: Text(
                    'View Details',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
