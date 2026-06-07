import 'package:flutter/material.dart';
import '../utils/app_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_colors.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';
import '../services/favorites_service.dart';
import '../services/reviews_service.dart';
import '../services/analytics_service.dart';
import '../l10n/app_localizations.dart';
import 'reviews_screen.dart';
import 'write_review_screen.dart';
import 'map_screen.dart';

class OverviewScreen extends StatefulWidget {
  final Place place;
  const OverviewScreen({super.key, required this.place});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final _pageCtrl = PageController();
  final _favService = FavoritesService();
  final _reviewsService = ReviewsService();
  final _analytics = AnalyticsService();
  bool _isFav = false;
  bool _favLoading = false;
  List<Review> _topReviews = [];
  late Place _place;
  String _distanceText = '...';

  @override
  void initState() {
    super.initState();
    _place = widget.place;
    _isFav = _place.isFavorite;
    _loadTopReviews();
    _loadDistance();
    _analytics.placeView(_place.id, _place.getName('en'));
  }

  Future<void> _loadDistance() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _distanceText = 'N/A');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final meters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        _place.location.latitude, _place.location.longitude,
      );
      final km = meters / 1000;
      final text = km < 1
          ? '${meters.round()} m'
          : '${km.toStringAsFixed(1)} KM';
      if (mounted) setState(() => _distanceText = text);
    } catch (_) {
      if (mounted) setState(() => _distanceText = 'N/A');
    }
  }

  Future<void> _sharePlace() async {
    final name = _place.getName('en');
    final desc = _place.getDescription('en');
    final shortDesc = desc.length > 100 ? '${desc.substring(0, 100)}...' : desc;
    final text = '🏛️ $name\n📍 ${_place.governorate}, Egypt\n⭐ ${_place.avgRating.toStringAsFixed(1)}\n\n$shortDesc\n\nDiscover Egypt App 🌍';

    await Share.share(text, subject: 'Visit $name in Egypt!');
    await _analytics.track(AnalyticsEvent.placeShare, data: {
      'place_id': _place.id,
      'place_name': name,
    });
  }

  Future<void> _loadTopReviews() async {
    try {
      final reviews = await _reviewsService.getReviews(_place.id, sort: 'highest');
      if (mounted) setState(() => _topReviews = reviews.take(3).toList());
    } catch (_) {}
  }

  Future<void> _toggleFav() async {
    setState(() => _favLoading = true);
    try {
      final isFav = await _favService.toggleFavorite(_place.id);
      setState(() => _isFav = isFav);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isFav ? '❤️ Added to favorites' : '💔 Removed from favorites'),
        backgroundColor: isFav ? AppColors.success : AppColors.textSecondary,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _openDirections() async {
    final lat = _place.location.latitude;
    final lng = _place.location.longitude;
    final url = Uri.parse('https://maps.google.com/maps?daddr=$lat,$lng');
    if (await canLaunchUrl(url)) launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final images = _place.images.isNotEmpty ? _place.images : [_place.coverImage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildImageAppBar(images),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageAppBar(List<String> images) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.secondary,
      leading: IconButton(
        icon: const CircleAvatar(
          backgroundColor: Colors.black45,
          child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Share button
        IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.black45,
            child: Icon(Icons.share_rounded, color: Colors.white, size: 18),
          ),
          onPressed: _sharePlace,
        ),
        // Favorite button
        _favLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : IconButton(
                icon: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: Icon(
                    _isFav ? Icons.favorite : Icons.favorite_border,
                    color: _isFav ? Colors.red : Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: _toggleFav,
              ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: images.length,
              itemBuilder: (_, i) => images[i].isEmpty
                  ? Container(
                      color: const Color(0xFF1A1F38),
                      child: const Center(
                          child: Icon(Icons.image_outlined,
                              size: 60, color: Colors.white24)))
                  : CachedNetworkImage(
                      imageUrl: images[i],
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 250),
                      placeholder: (_, __) =>
                          Container(color: AppColors.shimmerBase),
                      errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1A1F38),
                          child: const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  size: 60, color: Colors.white24))),
                    ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _pageCtrl,
                    count: images.length,
                    effect: const WormEffect(
                        dotHeight: 6, dotWidth: 6,
                        activeDotColor: Colors.white, dotColor: Colors.white38),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name & Category
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_place.getName('en'),
                        style: appFont(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(_place.getName('ar'),
                        style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              _CategoryBadge(_place.category),
            ],
          ),
          const SizedBox(height: 12),

          // Rating & Reviews
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.starColor, size: 20),
              const SizedBox(width: 4),
              Text(_place.avgRating.toStringAsFixed(1),
                  style: appFont(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Text('(${_place.reviewCount} reviews)',
                  style: appFont(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              const Icon(Icons.location_on, color: AppColors.accent, size: 16),
              const SizedBox(width: 4),
              Text(_place.governorate,
                  style: appFont(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 14),

          // ── Entry fee + Distance green pills ──────────────────────────────
          Row(
            children: [
              _greenPill(
                Icons.confirmation_number_outlined,
                _place.admissionFee.foreign == 0
                    ? 'Free Entry'
                    : 'Entry ${_place.admissionFee.foreign.toInt()} ${_place.admissionFee.currency}',
              ),
              const SizedBox(width: 10),
              _greenPill(
                Icons.near_me_outlined,
                _distanceText == 'N/A'
                    ? 'Distance N/A'
                    : 'Distance $_distanceText',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Location info row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_pin_circle_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _place.governorate,
                      style: appFont(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_place.governorate} Governorate, Egypt',
                      style: appFont(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Hours row ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_place.openingHours.open} - ${_place.openingHours.close}',
                      style: appFont(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _place.openingHours.days,
                      style: appFont(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
          const SizedBox(height: 16),

          // About
          Text(l10n.about, style: appFont(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_place.getDescription('en'),
              style: appFont(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.7)),

          const SizedBox(height: 16),

          // Tags
          if (_place.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _place.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: appFont(
                                fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Map Preview Button
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MapScreen(focusPlace: _place))),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_rounded, color: AppColors.secondary, size: 36),
                    const SizedBox(height: 8),
                    Text('View on Map',
                        style: appFont(
                            color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    Text('${_place.location.latitude.toStringAsFixed(4)}, ${_place.location.longitude.toStringAsFixed(4)}',
                        style: appFont(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Reviews Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.reviews, style: appFont(fontSize: 17, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ReviewsScreen(place: _place))),
                child: Text(l10n.seeAll,
                    style: appFont(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          // Rating summary card
          if (_place.reviewCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  // Big rating number
                  Column(
                    children: [
                      Text(
                        _place.avgRating.toStringAsFixed(1),
                        style: appFont(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < _place.avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.starColor,
                          size: 14,
                        )),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_place.reviewCount} reviews',
                        style: appFont(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Breakdown bars
                  Expanded(
                    child: Column(
                      children: [
                        _buildRatingBar(5, _place.ratingBreakdown.r5, _place.reviewCount),
                        _buildRatingBar(4, _place.ratingBreakdown.r4, _place.reviewCount),
                        _buildRatingBar(3, _place.ratingBreakdown.r3, _place.reviewCount),
                        _buildRatingBar(2, _place.ratingBreakdown.r2, _place.reviewCount),
                        _buildRatingBar(1, _place.ratingBreakdown.r1, _place.reviewCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No reviews yet. Be the first!',
                    style: appFont(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ),
          ],

          // Top Reviews
          ..._topReviews.map((r) => _ReviewTile(r)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: appFont(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, size: 11, color: AppColors.starColor),
          const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: AppColors.shimmerBase,
                valueColor: const AlwaysStoppedAnimation(AppColors.starColor),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: appFont(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions, color: AppColors.secondary),
                label: Text(l10n.getDirections,
                    style: appFont(color: AppColors.secondary, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => WriteReviewScreen(place: _place))),
                icon: const Icon(Icons.star_outline, color: Colors.white, size: 18),
                label: Text('Review',
                    style: appFont(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper inside state ───────────────────────────────────────────────────────
extension _OverviewHelpers on _OverviewScreenState {
  Widget _greenPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF16A34A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: appFont(
              fontSize: 12,
              color: const Color(0xFF16A34A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge(this.category);

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColors[category] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.toUpperCase(),
        style: appFont(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile(this.review);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 18,
                backgroundImage: review.user.avatarUrl.isNotEmpty
                    ? NetworkImage(review.user.avatarUrl)
                    : null,
                child: review.user.avatarUrl.isEmpty
                    ? Text(review.user.initials,
                        style: appFont(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.user.fullName,
                            style: appFont(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        if (review.user.country?.isNotEmpty == true) ...[
                          const SizedBox(width: 5),
                          Text(
                            _countryFlag(review.user.country!),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.stars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 12,
                          color: AppColors.starColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: appFont(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '';
    final code = countryCode.toUpperCase();
    return String.fromCharCodes(code.codeUnits.map((c) => c + 127397));
  }
}
