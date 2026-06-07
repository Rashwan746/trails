import 'package:flutter/material.dart';
import '../utils/app_font.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/place_model.dart';
import '../services/reviews_service.dart';

class WriteReviewScreen extends StatefulWidget {
  final Place place;
  const WriteReviewScreen({super.key, required this.place});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _reviewsService = ReviewsService();
  final _textCtrl = TextEditingController();
  double _stars = 0;
  bool _loading = false;
  final Set<String> _selectedTags = {};

  final List<String> _tags = [
    'History', 'Photography', 'Architecture', 'Family Friendly',
    'Adventure', 'Local Guides', 'Must Visit', 'Hidden Gem',
    'Budget Friendly', 'Romantic',
  ];

  final List<String> _ratingLabels = ['Terrible', 'Bad', 'Ok', 'Good', 'Excellent'];

  Future<void> _post() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_textCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please write at least 10 characters'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      await _reviewsService.postReview(
        placeId: widget.place.id,
        stars: _stars.round(),
        text: _textCtrl.text.trim(),
        tags: _selectedTags.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Review posted!'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancel,
            style: appFont(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
        ),
        leadingWidth: 80,
        title: Column(
          children: [
            Text(
              l10n.writeReview,
              style: appFont(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 3),
                Text(
                  widget.place.getName('en'),
                  style: appFont(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Rating stars centered
            Center(
              child: Column(
                children: [
                  RatingBar.builder(
                    initialRating: _stars,
                    minRating: 1,
                    itemCount: 5,
                    itemSize: 52,
                    glow: false,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star, color: AppColors.starColor),
                    onRatingUpdate: (r) => setState(() => _stars = r),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _stars == 0
                        ? Text(
                            'Tap to rate',
                            key: const ValueKey('tap'),
                            style: appFont(
                                color: AppColors.textSecondary, fontSize: 12.5),
                          )
                        : Text(
                            _ratingLabels[_stars.toInt() - 1].toUpperCase(),
                            key: ValueKey(_stars.toInt()),
                            style: appFont(
                                color: AppColors.starColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Add Photos section
            Text('Add Photos',
                style: appFont(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: Row(
                children: [
                  // Add button
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textSecondary, size: 22),
                        const SizedBox(height: 3),
                        Text('ADD',
                            style: appFont(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text('Your Experience',
                style: appFont(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),

            TextField(
              controller: _textCtrl,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Share your experience here...',
                hintStyle: appFont(color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text('Tag your interests',
                style: appFont(
                    fontWeight: FontWeight.bold, fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map((tag) => GestureDetector(
                        onTap: () => setState(() => _selectedTags.contains(tag)
                            ? _selectedTags.remove(tag)
                            : _selectedTags.add(tag)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTags.contains(tag)
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedTags.contains(tag)
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: appFont(
                              fontSize: 13,
                              color: _selectedTags.contains(tag)
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: _selectedTags.contains(tag)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _post,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Post',
                              style: appFont(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
