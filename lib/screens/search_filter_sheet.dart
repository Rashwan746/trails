import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class SearchFilters {
  final String? governorate;
  final String? placeType;
  final double distance;
  final double minRating;

  const SearchFilters({
    this.governorate,
    this.placeType,
    this.distance = 5.0,
    this.minRating = 3.0,
  });

  SearchFilters copyWith({
    String? governorate,
    String? placeType,
    double? distance,
    double? minRating,
  }) {
    return SearchFilters(
      governorate: governorate ?? this.governorate,
      placeType:   placeType   ?? this.placeType,
      distance:    distance    ?? this.distance,
      minRating:   minRating   ?? this.minRating,
    );
  }
}

class SearchFilterSheet extends StatefulWidget {
  final SearchFilters initial;
  final int resultCount;
  const SearchFilterSheet(
      {super.key, required this.initial, this.resultCount = 0});

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late String? _governorate;
  late String? _placeType;
  late double  _distance;
  late double  _minRating;

  int  _liveCount    = 0;
  bool _countLoading = false;

  final _api = ApiService();

  final List<Map<String, dynamic>> _governorates = [
    {'id': 'nearby',     'label': 'Nearby',     'icon': Icons.near_me_rounded},
    {'id': 'cairo',      'label': 'Cairo',      'icon': null},
    {'id': 'giza',       'label': 'Giza',       'icon': null},
    {'id': 'alexandria', 'label': 'Alexandria', 'icon': null},
    {'id': 'luxor',      'label': 'Luxor',      'icon': null},
    {'id': 'aswan',      'label': 'Aswan',      'icon': null},
    {'id': 'hurghada',   'label': 'Hurghada',   'icon': null},
    {'id': 'sharm',      'label': 'Sharm',      'icon': null},
  ];

  // (id, label, icon, db_category)
  static const _placeTypes = [
    ('all',         'All',        Icons.public_rounded,          null),
    ('historical',  'Sights',     Icons.account_balance_rounded, 'historical'),
    ('restaurant',  'Dining',     Icons.restaurant_rounded,      'restaurant'),
    ('hotel',       'Hotels',     Icons.bed_rounded,             'hotel'),
    ('market',      'Shops',      Icons.storefront_rounded,      'market'),
    ('beach',       'Beaches',    Icons.beach_access_rounded,    'beach'),
    ('nature',      'Nature',     Icons.forest_rounded,          'nature'),
    ('museum',      'Museums',    Icons.museum_rounded,          'museum'),
    ('religious',   'Religious',  Icons.mosque_rounded,          'religious'),
    ('desert',      'Desert',     Icons.wb_sunny_rounded,        'desert'),
  ];

  @override
  void initState() {
    super.initState();
    _governorate = widget.initial.governorate ?? 'nearby';
    _placeType   = widget.initial.placeType   ?? 'all';
    _distance    = widget.initial.distance;
    _minRating   = widget.initial.minRating;
    _liveCount   = widget.resultCount;
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    setState(() => _countLoading = true);
    try {
      // find db category key (null = all)
      String? cat;
      for (final t in _placeTypes) {
        if (t.$1 == _placeType) { cat = t.$4; break; }
      }

      // build params — go directly to API to bypass cache
      final params = <String, dynamic>{'limit': '1', 'offset': '0'};
      if (cat != null) params['category'] = cat;
      if (_minRating > 0) params['min_rating'] = _minRating.toString();

      final res = await _api.get('/places', params: params);
      final count = (res['total'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _liveCount = count);
    } catch (e) {
      debugPrint('FilterCount error: $e');
    }
    if (mounted) setState(() => _countLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Governorate ────────────────────────────────
                  _sectionTitle('Governorate', trailing: _buildViewMapBtn()),
                  const SizedBox(height: 12),
                  _buildGovernorateChips(),
                  const SizedBox(height: 24),

                  // ── Place Type ─────────────────────────────────
                  _sectionTitle('Place Type'),
                  const SizedBox(height: 12),
                  _buildPlaceTypeChips(),
                  const SizedBox(height: 24),

                  // ── Distance ───────────────────────────────────
                  _sectionTitle('Distance',
                      trailing: Text('Within ${_distance.toInt()} km',
                        style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500))),
                  const SizedBox(height: 4),
                  _buildDistanceSlider(),
                  const SizedBox(height: 24),

                  // ── Minimum Rating ─────────────────────────────
                  _sectionTitle('Minimum Rating'),
                  const SizedBox(height: 12),
                  _buildRatingOptions(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Show Places button ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            color: Colors.white,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                SearchFilters(
                  governorate: _governorate,
                  placeType:   _placeType,
                  distance:    _distance,
                  minRating:   _minRating,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_countLoading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  else
                    Text(
                      'Show $_liveCount Places',
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
          style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildViewMapBtn() {
    return GestureDetector(
      onTap: () {},
      child: Text('View Map',
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }

  // ── Governorate chips ─────────────────────────────────────────────────────
  Widget _buildGovernorateChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _governorates.map((gov) {
          final isSelected = _governorate == gov['id'];
          return GestureDetector(
            onTap: () { setState(() => _governorate = gov['id']); _fetchCount(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: gov['icon'] != null ? 12 : 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (gov['icon'] != null) ...[
                    Icon(gov['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : AppColors.textSecondary),
                    const SizedBox(width: 4),
                  ],
                  Text(gov['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Place type — favorites-style horizontal scroll ────────────────────────
  Widget _buildPlaceTypeChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _placeTypes.length,
        itemBuilder: (_, i) {
          final (id, label, icon, _) = _placeTypes[i];
          final isSelected = _placeType == id;
          return GestureDetector(
            onTap: () { setState(() => _placeType = id); _fetchCount(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14,
                    color: isSelected ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Distance slider ───────────────────────────────────────────────────────
  Widget _buildDistanceSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor:   AppColors.primary,
            inactiveTrackColor: AppColors.divider,
            thumbColor:         AppColors.primary,
            overlayColor:       AppColors.primary.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value: _distance, min: 1, max: 50, divisions: 49,
            onChanged: (v) { setState(() => _distance = v); },
            onChangeEnd: (_) => _fetchCount(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km',  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight)),
              Text('50 km', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Rating options with correct partial stars ─────────────────────────────
  Widget _buildRatingOptions() {
    final options = [4.0, 3.0, 2.0];
    return Row(
      children: options.map((rating) {
        final isSelected  = _minRating == rating;
        final filledCount = rating.toInt(); // 4, 3, or 2 filled stars

        return Expanded(
          child: GestureDetector(
            onTap: () { setState(() => _minRating = rating); _fetchCount(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: rating == options.last ? 0 : 10),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stars row — filled count matches rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < filledCount;
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14,
                        color: filled
                            ? (isSelected ? AppColors.starColor : AppColors.starColor.withOpacity(0.55))
                            : (isSelected ? AppColors.starColor.withOpacity(0.25) : AppColors.divider),
                      );
                    }),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${rating.toStringAsFixed(1)}+',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
