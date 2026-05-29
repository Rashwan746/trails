import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple local cache with TTL support.
/// Used for offline-first experience.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const _prefix = 'cache_';
  static const _tsPrefix = 'cache_ts_';

  // Default TTL values
  static const Duration featuredTTL = Duration(hours: 6);
  static const Duration placesTTL = Duration(hours: 2);
  static const Duration nearbyTTL = Duration(minutes: 30);
  static const Duration favoritesTTL = Duration(minutes: 15);
  static const Duration placeDetailTTL = Duration(hours: 12);

  /// Save JSON data to cache with a TTL
  Future<void> set(String key, dynamic data, {Duration ttl = placesTTL}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + key, jsonEncode(data));
    await prefs.setInt(_tsPrefix + key, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('${_tsPrefix}${key}_ttl', ttl.inMilliseconds);
  }

  /// Get cached data if still valid. Returns null if expired or missing.
  Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;

    final ts = prefs.getInt(_tsPrefix + key) ?? 0;
    final ttlMs = prefs.getInt('${_tsPrefix}${key}_ttl') ?? placesTTL.inMilliseconds;
    final age = DateTime.now().millisecondsSinceEpoch - ts;

    if (age > ttlMs) {
      // Expired — remove
      await _remove(key, prefs);
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Get cached data even if expired (for offline fallback)
  Future<dynamic> getStale(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Remove a specific key
  Future<void> _remove(String key, SharedPreferences prefs) async {
    await prefs.remove(_prefix + key);
    await prefs.remove(_tsPrefix + key);
    await prefs.remove('${_tsPrefix}${key}_ttl');
  }

  /// Clear all cache entries
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Check if a key has valid cache
  Future<bool> isValid(String key) async {
    final data = await get(key);
    return data != null;
  }
}
