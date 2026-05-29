import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/place_model.dart';
import '../services/places_service.dart';
import '../services/analytics_service.dart';
import '../widgets/place_card.dart';
import 'overview_screen.dart';
import 'search_filter_sheet.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;
  const SearchScreen({super.key, this.initialCategory});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _placesService = PlacesService();
  final _analytics = AnalyticsService();
  final _searchCtrl = TextEditingController();
  List<Place> _results = [];
  bool _loading = false;
  String? _selectedCategory;
  int _total = 0;
  SearchFilters _filters = const SearchFilters();

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'All', 'emoji': '🌍'},
    {'id': 'historical', 'label': 'Historical', 'emoji': '🏛️'},
    {'id': 'beach', 'label': 'Beach', 'emoji': '🏖️'},
    {'id': 'desert', 'label': 'Desert', 'emoji': '🏜️'},
    {'id': 'museum', 'label': 'Museum', 'emoji': '🏺'},
    {'id': 'religious', 'label': 'Religious', 'emoji': '🕌'},
    {'id': 'nature', 'label': 'Nature', 'emoji': '🌿'},
    {'id': 'market', 'label': 'Market', 'emoji': '🛍️'},
    {'id': 'cruise', 'label': 'Cruise', 'emoji': '🚢'},
    {'id': 'restaurant', 'label': 'Restaurants', 'emoji': '🍽️'},
    {'id': 'hotel', 'label': 'Hotels', 'emoji': '🏨'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _search();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SearchFilterSheet(
          initial: _filters,
          resultCount: _total,
        ),
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
      _search();
    }
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      _analytics.track(AnalyticsEvent.searchPerformed, data: {
        'query': query,
        'category': _selectedCategory,
      });
    }
    setState(() => _loading = true);
    try {
      final res = await _placesService.getPlaces(
        search: query,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        limit: 30,
      );
      setState(() {
        _results = res['places'];
        _total = res['total'];
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Explore Egypt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          if (!_loading && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text('$_total places found',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: (_) => _search(),
        onChanged: (v) { if (v.isEmpty) _search(); },
        decoration: InputDecoration(
          hintText: 'Search pyramids, beaches, Cairo...',
          hintStyle: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () { _searchCtrl.clear(); _search(); })
              : IconButton(
                  icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                  onPressed: _openFilters,
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = (_selectedCategory ?? 'all') == cat['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat['id']);
              _search();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
              ),
              child: Text(
                '${cat['emoji']} ${cat['label']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('No places found',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('Try a different search or category',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (_, i) => NearbyPlaceCard(
        place: _results[i],
        locale: 'en',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => OverviewScreen(place: _results[i]))),
      ),
    );
  }
}
