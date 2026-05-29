import 'api_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import '../models/place_model.dart';

class PlacesService {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  Future<List<Place>> getFeatured() async {
    const cacheKey = 'featured_places';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res = await _api.get('/places/featured');
        final places = (res['data'] as List).map((j) => Place.fromJson(j)).toList();
        // Save to cache
        await _cache.set(cacheKey, res['data'], ttl: CacheService.featuredTTL);
        return places;
      } catch (_) {
        // Fall through to cache
      }
    }

    // Offline fallback — use stale cache
    final cached = await _cache.getStale(cacheKey);
    if (cached != null) {
      return (cached as List).map((j) => Place.fromJson(j)).toList();
    }
    return [];
  }

  Future<List<Place>> getNearby({double? lat, double? lng, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;

    final cacheKey = 'nearby_${lat?.toStringAsFixed(2)}_${lng?.toStringAsFixed(2)}';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res = await _api.get('/places/nearby', params: params);
        final places = (res['data'] as List).map((j) => Place.fromJson(j)).toList();
        await _cache.set(cacheKey, res['data'], ttl: CacheService.nearbyTTL);
        return places;
      } catch (_) {}
    }

    final cached = await _cache.getStale(cacheKey) ??
        await _cache.getStale('nearby_null_null');
    if (cached != null) {
      return (cached as List).map((j) => Place.fromJson(j)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getPlaces({
    String? category,
    String? governorate,
    String? search,
    double? minRating,
    String? tag,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (category != null && category != 'All') params['category'] = category;
    if (governorate != null) params['governorate'] = governorate;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (minRating != null) params['min_rating'] = minRating;
    if (tag != null) params['tag'] = tag;

    final cacheKey = 'places_${category}_${search}_${offset}';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res = await _api.get('/places', params: params);
        final result = {
          'places': (res['data'] as List).map((j) => Place.fromJson(j)).toList(),
          'total': res['total'] ?? 0,
        };
        // Cache first page only
        if (offset == 0) {
          await _cache.set(cacheKey, {'data': res['data'], 'total': res['total']},
              ttl: CacheService.placesTTL);
        }
        return result;
      } catch (_) {}
    }

    // Offline fallback
    if (offset == 0) {
      final cached = await _cache.getStale(cacheKey);
      if (cached != null) {
        return {
          'places': (cached['data'] as List).map((j) => Place.fromJson(j)).toList(),
          'total': cached['total'] ?? 0,
        };
      }
    }

    return {'places': <Place>[], 'total': 0};
  }

  Future<Place> getPlace(String id) async {
    final cacheKey = 'place_$id';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res = await _api.get('/places/$id');
        await _cache.set(cacheKey, res['data'], ttl: CacheService.placeDetailTTL);
        return Place.fromJson(res['data']);
      } catch (_) {}
    }

    final cached = await _cache.getStale(cacheKey);
    if (cached != null) return Place.fromJson(cached);
    throw Exception('Place not available offline');
  }

  Future<List<Place>> getRecommendations(List<String> interests, {int limit = 10}) async {
    final res = await _api.get('/places/recommendations', params: {
      'interests': interests.join(','),
      'limit': limit,
    });
    return (res['data'] as List).map((j) => Place.fromJson(j)).toList();
  }

  Future<List<String>> getCategories() async {
    final res = await _api.get('/places/categories');
    return (res['data'] as List).map((c) => c['id'].toString()).toList();
  }

  Future<List<String>> getGovernorates() async {
    const cacheKey = 'governorates';
    final cached = await _cache.get(cacheKey);
    if (cached != null) return List<String>.from(cached);

    final res = await _api.get('/places/governorates');
    await _cache.set(cacheKey, res['data'], ttl: const Duration(hours: 24));
    return List<String>.from(res['data']);
  }
}
