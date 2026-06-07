import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/app_font.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';
import '../models/place_model.dart';
import '../services/favorites_service.dart';

// ─── Featured Horizontal Card ────────────────────────────────────────────────
class FeaturedPlaceCard extends StatelessWidget {
  final Place place;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback? onFavTap;

  const FeaturedPlaceCard({
    super.key,
    required this.place,
    required this.locale,
    required this.onTap,
    this.onFavTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _PlaceImage(url: place.displayImage),

              // Gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.4, 1.0],
                  ),
                ),
              ),

              // Favorite button
              Positioned(
                top: 10,
                right: 10,
                child: _FavButton(place: place, onTap: onFavTap),
              ),

              // Bottom info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges row: rating + MOST RECOMMENDED
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFC107), size: 13),
                              const SizedBox(width: 4),
                              Text(
                                place.avgRating.toStringAsFixed(1),
                                style: appFont(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'MOST RECOMMENDED',
                            style: appFont(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place.getName(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 12),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place.governorate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(color: Colors.white70, fontSize: 11),
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
}

// ─── Nearby / Search Vertical Card ───────────────────────────────────────────
class NearbyPlaceCard extends StatefulWidget {
  final Place place;
  final String locale;
  final VoidCallback onTap;

  const NearbyPlaceCard({
    super.key,
    required this.place,
    required this.locale,
    required this.onTap,
  });

  @override
  State<NearbyPlaceCard> createState() => _NearbyPlaceCardState();
}

class _NearbyPlaceCardState extends State<NearbyPlaceCard> {
  final _favService = FavoritesService();
  bool _loading = false;

  Future<void> _toggle() async {
    if (_loading) return;
    // Optimistic UI update
    final wasF = widget.place.isFavorite;
    setState(() {
      _loading = true;
      widget.place.isFavorite = !wasF;
    });
    try {
      final isFav = await _favService.toggleFavorite(widget.place.id);
      if (mounted) setState(() => widget.place.isFavorite = isFav);
    } catch (e) {
      // Revert optimistic change on failure
      if (mounted) {
        setState(() => widget.place.isFavorite = wasF);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            e.toString().contains('401') || e.toString().contains('authorized')
                ? 'Please log in to save favorites'
                : 'Could not update favorite. Please try again.',
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: _PlaceImage(url: widget.place.displayImage),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.place.getName(widget.locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appFont(
                                fontWeight: FontWeight.bold, fontSize: 14,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (_loading)
                          const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        else
                          GestureDetector(
                            onTap: _toggle,
                            child: Icon(
                              widget.place.isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: widget.place.isFavorite ? Colors.red : AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.accent, size: 13),
                        const SizedBox(width: 3),
                        Text(widget.place.governorate,
                            style: appFont(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.place.getDescription(widget.locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                          color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _RatingBadge(rating: widget.place.avgRating, small: true),
                        const SizedBox(width: 6),
                        Text('(${widget.place.reviewCount})',
                            style: appFont(
                                color: AppColors.textLight, fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (AppColors.categoryColors[widget.place.category] ??
                                    AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.place.category,
                            style: appFont(
                              fontSize: 10,
                              color: AppColors.categoryColors[widget.place.category] ??
                                  AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Components ────────────────────────────────────────────────────────

class _PlaceImage extends StatelessWidget {
  final String url;
  const _PlaceImage({required this.url});

  static const _placeholder = Color(0xFFE8E9EC);
  static const _iconColor = Color(0xFFB0B7C3);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: _placeholder,
        child: const Center(
          child: Icon(Icons.image_outlined, color: _iconColor, size: 40),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(color: AppColors.shimmerBase),
      ),
      errorWidget: (_, __, ___) => Container(
        color: _placeholder,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: _iconColor, size: 40),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  final bool small;
  const _RatingBadge({required this.rating, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(small ? 8 : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: AppColors.starColor, size: small ? 11 : 13),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: appFont(
                color: Colors.white, fontSize: small ? 11 : 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _FavButton extends StatefulWidget {
  final Place place;
  final VoidCallback? onTap;
  const _FavButton({required this.place, this.onTap});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  final _favService = FavoritesService();
  bool _loading = false;

  Future<void> _toggle() async {
    if (_loading) return;
    final wasF = widget.place.isFavorite;
    setState(() {
      _loading = true;
      widget.place.isFavorite = !wasF;
    });
    try {
      final isFav = await _favService.toggleFavorite(widget.place.id);
      if (mounted) setState(() => widget.place.isFavorite = isFav);
      // Note: do NOT call widget.onTap here — parent already has the updated
      // place reference and calling it would toggle the value back again.
    } catch (e) {
      if (mounted) {
        setState(() => widget.place.isFavorite = wasF);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            e.toString().contains('401') || e.toString().contains('authorized')
                ? 'Please log in to save favorites'
                : 'Could not update favorite. Please try again.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(
                widget.place.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.place.isFavorite ? Colors.red : Colors.white,
                size: 16,
              ),
      ),
    );
  }
}
