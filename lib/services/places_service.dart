import 'api_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import 'local_db_service.dart';
import '../models/place_model.dart';

/// PlacesService — Local SQLite is the PRIMARY source.
/// API calls are attempted as a background update when online,
/// but the app never blocks waiting for the network.
class PlacesService {
  final ApiService          _api          = ApiService();
  final CacheService        _cache        = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();
  final LocalDbService      _localDb      = LocalDbService();

  // ── Featured ──────────────────────────────────────────────────────────────

  Future<List<Place>> getFeatured() async {
    // 1. Local DB (always works offline)
    try {
      final rows = await _localDb.getFeatured(limit: 12);
      if (rows.isNotEmpty) {
        return rows.map((j) => Place.fromJson(j)).toList();
      }
    } catch (_) {}

    // 2. Cache fallback
    const cacheKey = 'featured_places';
    final isOnline = await _connectivity.isOnline();
    if (isOnline) {
      try {
        final res    = await _api.get('/places/featured');
        final places = (res['data'] as List).map((j) => Place.fromJson(j)).toList();
        await _cache.set(cacheKey, res['data'], ttl: CacheService.featuredTTL);
        return places;
      } catch (_) {}
    }

    final cached = await _cache.getStale(cacheKey);
    if (cached != null) {
      return (cached as List).map((j) => Place.fromJson(j)).toList();
    }
    return [];
  }

  // ── Nearby ────────────────────────────────────────────────────────────────

  Future<List<Place>> getNearby({double? lat, double? lng, int limit = 20}) async {
    // 1. Local DB
    try {
      final rows = await _localDb.getNearby(lat: lat, lng: lng, limit: limit);
      if (rows.isNotEmpty) {
        return rows.map((j) => Place.fromJson(j)).toList();
      }
    } catch (_) {}

    // 2. API / Cache
    final params   = <String, dynamic>{'limit': limit};
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    final cacheKey = 'nearby_${lat?.toStringAsFixed(2)}_${lng?.toStringAsFixed(2)}';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res    = await _api.get('/places/nearby', params: params);
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

  // ── Places list ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlaces({
    String? category,
    String? governorate,
    String? search,
    double? minRating,
    String? tag,
    int limit = 20,
    int offset = 0,
  }) async {
    // 1. Local DB
    try {
      final result = await _localDb.getPlaces(
        category:    category,
        governorate: governorate,
        search:      search,
        minRating:   minRating,
        tag:         tag,
        limit:       limit,
        offset:      offset,
      );
      final places = (result['places'] as List)
          .map((j) => Place.fromJson(j as Map<String, dynamic>))
          .toList();
      if (places.isNotEmpty || offset > 0) {
        return {'places': places, 'total': result['total']};
      }
    } catch (_) {}

    // 2. API / Cache
    final params   = <String, dynamic>{'limit': limit, 'offset': offset};
    if (category != null && category != 'All') params['category'] = category;
    if (governorate != null)                    params['governorate'] = governorate;
    if (search != null && search.isNotEmpty)    params['search'] = search;
    if (minRating != null)                      params['min_rating'] = minRating;
    if (tag != null)                            params['tag'] = tag;

    final cacheKey = 'places_${category}_${search}_$offset';
    final isOnline = await _connectivity.isOnline();

    if (isOnline) {
      try {
        final res = await _api.get('/places', params: params);
        final result = {
          'places': (res['data'] as List).map((j) => Place.fromJson(j)).toList(),
          'total':  res['total'] ?? 0,
        };
        if (offset == 0) {
          await _cache.set(cacheKey, {'data': res['data'], 'total': res['total']},
              ttl: CacheService.placesTTL);
        }
        return result;
      } catch (_) {}
    }

    if (offset == 0) {
      final cached = await _cache.getStale(cacheKey);
      if (cached != null) {
        return {
          'places': (cached['data'] as List).map((j) => Place.fromJson(j)).toList(),
          'total':  cached['total'] ?? 0,
        };
      }
    }

    return {'places': <Place>[], 'total': 0};
  }

  // ── Single place ──────────────────────────────────────────────────────────

  Future<Place> getPlace(String id) async {
    // 1. Local DB
    try {
      final row = await _localDb.getPlace(id);
      if (row != null) return Place.fromJson(row);
    } catch (_) {}

    // 2. API / Cache
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
    throw Exception('Place not available');
  }

  // ── Recommendations ───────────────────────────────────────────────────────

  Future<List<Place>> getRecommendations(List<String> interests,
      {int limit = 10}) async {
    // 1. Local DB
    try {
      final rows = await _localDb.getRecommendations(interests, limit: limit);
      if (rows.isNotEmpty) {
        return rows.map((j) => Place.fromJson(j)).toList();
      }
    } catch (_) {}

    // 2. API
    try {
      final res = await _api.get('/places/recommendations', params: {
        'interests': interests.join(','),
        'limit': limit,
      });
      return (res['data'] as List).map((j) => Place.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Categories & Governorates ─────────────────────────────────────────────

  Future<List<String>> getCategories() async {
    // 1. Local DB
    try {
      final cats = await _localDb.getCategories();
      if (cats.isNotEmpty) return cats;
    } catch (_) {}

    // 2. API
    try {
      final res = await _api.get('/places/categories');
      return (res['data'] as List).map((c) => c['id'].toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getGovernorates() async {
    const cacheKey = 'governorates';

    // 1. Local DB
    try {
      final govs = await _localDb.getGovernorates();
      if (govs.isNotEmpty) return govs;
    } catch (_) {}

    // 2. Cache / API
    final cached = await _cache.get(cacheKey);
    if (cached != null) return List<String>.from(cached);

    try {
      final res = await _api.get('/places/governorates');
      await _cache.set(cacheKey, res['data'], ttl: const Duration(hours: 24));
      return List<String>.from(res['data']);
    } catch (_) {
      return [];
    }
  }
}
