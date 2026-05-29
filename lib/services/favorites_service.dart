import 'api_service.dart';
import '../models/place_model.dart';

class FavoritesService {
  final ApiService _api = ApiService();

  Future<List<Place>> getFavorites({String? category}) async {
    final params = <String, dynamic>{};
    if (category != null && category != 'All') params['category'] = category;
    final res = await _api.get('/favorites', params: params);
    return (res['data'] as List).map((j) => Place.fromJson(j)).toList();
  }

  Future<bool> toggleFavorite(String placeId) async {
    final res = await _api.post('/favorites/$placeId/toggle', {});
    return res['is_favorite'] ?? false;
  }

  Future<bool> isFavorite(String placeId) async {
    final res = await _api.get('/favorites/check/$placeId');
    return res['is_favorite'] ?? false;
  }
}
