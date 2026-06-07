import 'api_service.dart';
import '../models/review_model.dart';

class ReviewsService {
  final ApiService _api = ApiService();

  Future<List<Review>> getReviews(String placeId, {String sort = 'newest'}) async {
    final res = await _api.get('/reviews/place/$placeId', params: {'sort': sort});
    return (res['data'] as List).map((j) => Review.fromJson(j)).toList();
  }

  Future<Review> postReview({
    required String placeId,
    required int stars,
    required String text,
    List<String> tags = const [],
    List<String> images = const [],
  }) async {
    final res = await _api.post('/reviews', {
      'place_id': placeId,
      'stars': stars,
      'text': text,
      'tags': tags,
      'images': images,
    });
    return Review.fromJson(res['data']);
  }

  Future<Map<String, dynamic>> markHelpful(String reviewId) async {
    return await _api.post('/reviews/$reviewId/helpful', {});
  }
}
