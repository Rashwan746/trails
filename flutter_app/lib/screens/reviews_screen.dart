import 'package:flutter/material.dart';
import '../utils/app_font.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';
import '../services/reviews_service.dart';
import 'write_review_screen.dart';

class ReviewsScreen extends StatefulWidget {
  final Place place;
  const ReviewsScreen({super.key, required this.place});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _reviewsService = ReviewsService();
  List<Review> _reviews = [];
  bool _loading = true;
  String _sort = 'newest';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reviews = await _reviewsService.getReviews(widget.place.id, sort: _sort);
      setState(() => _reviews = reviews);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markHelpful(Review review) async {
    try {
      final res = await _reviewsService.markHelpful(review.id);
      setState(() => review.helpfulCount = res['helpful_count'] ?? review.helpfulCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(l10n.reviews,
                style: appFont(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            Text(widget.place.getName('en'),
                style: appFont(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          _buildRatingSummary(),
          _buildSortBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _reviews.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _reviews.length,
                          itemBuilder: (_, i) => _ReviewCard(
                            review: _reviews[i],
                            onHelpful: () => _markHelpful(_reviews[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WriteReviewScreen(place: widget.place)));
            _load();
          },
          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          label: Text(l10n.writeReview,
              style: appFont(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSummary() {
    final place = widget.place;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big rating number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.avgRating.toStringAsFixed(1),
                style: appFont(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
              ),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < place.avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.starColor,
                          size: 16,
                        )),
              ),
              const SizedBox(height: 2),
              Text(
                '${place.reviewCount} reviews',
                style: appFont(
                    color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(width: 20),
          // Rating bars
          Expanded(
            child: Column(
              children: [
                _ratingBar(5, place.ratingBreakdown.r5, place.reviewCount),
                _ratingBar(4, place.ratingBreakdown.r4, place.reviewCount),
                _ratingBar(3, place.ratingBreakdown.r3, place.reviewCount),
                _ratingBar(2, place.ratingBreakdown.r2, place.reviewCount),
                _ratingBar(1, place.ratingBreakdown.r1, place.reviewCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(int stars, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    final pctText = '${(pct * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text('$stars',
              style: appFont(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 3),
          const Icon(Icons.star_rounded, size: 11, color: AppColors.starColor),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.shimmerBase,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.starColor),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              pctText,
              textAlign: TextAlign.right,
              style: appFont(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SortChip('newest', l10n.sortNewest, _sort, Icons.sort_rounded, () {
              setState(() => _sort = 'newest');
              _load();
            }),
            const SizedBox(width: 8),
            _SortChip('highest', l10n.sortHighest, _sort, Icons.star_rounded, () {
              setState(() => _sort = 'highest');
              _load();
            }),
            const SizedBox(width: 8),
            _SortChip('photos', l10n.sortPhotos, _sort, Icons.photo_library_outlined, () {
              setState(() => _sort = 'photos');
              _load();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(l10n.noReviews,
              style: appFont(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Be the first to review!',
              style: appFont(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String value, label, current;
  final IconData icon;
  final VoidCallback onTap;
  const _SortChip(this.value, this.label, this.current, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: appFont(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onHelpful;
  const _ReviewCard({required this.review, required this.onHelpful});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} Sec ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 20,
                backgroundImage: review.user.avatarUrl.isNotEmpty
                    ? NetworkImage(review.user.avatarUrl)
                    : null,
                child: review.user.avatarUrl.isEmpty
                    ? Text(review.user.initials,
                        style: appFont(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.user.fullName,
                            style: appFont(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(width: 6),
                        if (review.user.country?.isNotEmpty == true)
                          Text(
                            _countryFlag(review.user.country!),
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < review.stars
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 14,
                              color: AppColors.starColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(review.createdAt),
                          style: appFont(
                              color: AppColors.textLight, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Review text
          Text(
            review.text,
            style: appFont(
                color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),

          // Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(t,
                            style: appFont(
                                fontSize: 11, color: AppColors.primary)),
                      ))
                  .toList(),
            ),
          ],

          // Photo grid (2x2 with +X overlay)
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildPhotoGrid(review.images),
          ],

          const SizedBox(height: 10),

          // Helpful + Reply row
          Row(
            children: [
              GestureDetector(
                onTap: onHelpful,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.thumb_up_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        '${l10n.helpful} (${review.helpfulCount})',
                        style: appFont(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      'Reply',
                      style: appFont(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> images) {
    final count = images.length;
    final show = count > 4 ? 4 : count;
    final extra = count - 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.5,
      ),
      itemCount: show,
      itemBuilder: (_, i) {
        final isLast = i == 3 && extra > 0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(images[i], fit: BoxFit.cover),
              if (isLast)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+$extra',
                      style: appFont(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return '';
    final code = countryCode.toUpperCase();
    return String.fromCharCodes(
        code.codeUnits.map((c) => c + 127397));
  }
}
