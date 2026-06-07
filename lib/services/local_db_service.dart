import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// LocalDbService — reads the bundled SQLite database (assets/db/discover_egypt.db)
/// and exposes query methods that mirror the backend API responses.
class LocalDbService {
  static const String _dbAssetPath = 'assets/db/discover_egypt.db';
  static const String _dbFileName  = 'discover_egypt.db';

  static LocalDbService? _instance;
  static Database? _db;

  LocalDbService._();

  factory LocalDbService() {
    _instance ??= LocalDbService._();
    return _instance!;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, _dbFileName);

    // Copy from assets on first install (or when bundled file is newer)
    await _copyAssetIfNeeded(dbPath);

    return openDatabase(dbPath, readOnly: true);
  }

  Future<void> _copyAssetIfNeeded(String dbPath) async {
    final file = File(dbPath);
    if (!file.existsSync()) {
      // First install — copy from bundle
      final data = await rootBundle.load(_dbAssetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes, flush: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Convert a DB row to the JSON shape that Place.fromJson() expects.
  Future<Map<String, dynamic>> _rowToJson(
      Map<String, dynamic> row, List<Map<String, dynamic>> images) async {
    final imageUrls = images.map((i) => i['image_url'] as String).toList();
    return {
      '_id': row['id'].toString(),
      'id':  row['id'].toString(),
      'name': {
        'en': row['name_en'] ?? '',
        'ar': row['name_ar'] ?? '',
      },
      'description': {
        'en': row['desc_en'] ?? '',
        'ar': row['desc_ar'] ?? '',
      },
      'category':    row['category'] ?? '',
      'governorate': row['governorate'] ?? '',
      'location': {
        'coordinates': [row['longitude'] ?? 0.0, row['latitude'] ?? 0.0],
        'address': row['address'] ?? '',
      },
      'images':      imageUrls,
      'cover_image': imageUrls.isNotEmpty ? imageUrls.first : '',
      'admission_fee': {
        'egyptian': row['fee_egyptian'] ?? 0,
        'foreign':  row['fee_foreign']  ?? 0,
        'currency': 'EGP',
      },
      'opening_hours': {
        'open':  row['hours_open']  ?? '09:00',
        'close': row['hours_close'] ?? '18:00',
        'days':  row['hours_days']  ?? 'Daily',
      },
      'tags':         _parseTags(row['tags']),
      'is_featured':  (row['is_featured'] ?? 0) == 1,
      'avg_rating':   (row['avg_rating'] ?? 0).toDouble(),
      'review_count': row['review_count'] ?? 0,
      'rating_breakdown': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
    };
  }

  List<String> _parseTags(dynamic raw) {
    if (raw == null || (raw as String).isEmpty) return [];
    return raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  Future<List<Map<String, dynamic>>> _imagesFor(int placeId) async {
    final db = await database;
    return db.query('place_images',
        where: 'place_id = ?',
        whereArgs: [placeId],
        orderBy: 'sort_order ASC');
  }

  Future<List<Map<String, dynamic>>> _toJsonList(
      List<Map<String, dynamic>> rows) async {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final imgs = await _imagesFor(row['id'] as int);
      result.add(await _rowToJson(row, imgs));
    }
    return result;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Featured places (is_featured = 1), up to [limit].
  Future<List<Map<String, dynamic>>> getFeatured({int limit = 12}) async {
    final db = await database;
    final rows = await db.query('places',
        where: 'is_featured = 1',
        orderBy: 'avg_rating DESC',
        limit: limit);
    return _toJsonList(rows);
  }

  /// Nearby places sorted by distance (approximate, uses lat/lng).
  Future<List<Map<String, dynamic>>> getNearby({
    double? lat,
    double? lng,
    int limit = 20,
  }) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (lat != null && lng != null) {
      // Simple bounding-box proximity filter (±2 degrees ≈ 220 km)
      rows = await db.rawQuery('''
        SELECT *,
          ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS dist
        FROM places
        WHERE latitude != 0 AND longitude != 0
        ORDER BY dist ASC
        LIMIT ?
      ''', [lat, lat, lng, lng, limit]);
    } else {
      rows = await db.query('places',
          where: 'is_featured = 1',
          orderBy: 'avg_rating DESC',
          limit: limit);
    }
    return _toJsonList(rows);
  }

  /// Paginated places with optional filters.
  Future<Map<String, dynamic>> getPlaces({
    String? category,
    String? governorate,
    String? search,
    double? minRating,
    String? tag,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await database;
    final where  = <String>[];
    final args   = <dynamic>[];

    if (category != null && category != 'All' && category.isNotEmpty) {
      where.add('LOWER(category) = LOWER(?)');
      args.add(category);
    }
    if (governorate != null && governorate.isNotEmpty) {
      where.add('LOWER(governorate) = LOWER(?)');
      args.add(governorate);
    }
    if (search != null && search.isNotEmpty) {
      where.add('(LOWER(name_en) LIKE ? OR LOWER(name_ar) LIKE ?)');
      args.add('%${search.toLowerCase()}%');
      args.add('%${search.toLowerCase()}%');
    }
    if (minRating != null) {
      where.add('avg_rating >= ?');
      args.add(minRating);
    }
    if (tag != null && tag.isNotEmpty) {
      where.add('tags LIKE ?');
      args.add('%$tag%');
    }

    final whereStr = where.isEmpty ? null : where.join(' AND ');

    // Count
    final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM places ${whereStr != null ? "WHERE $whereStr" : ""}',
        args);
    final total = (countResult.first['cnt'] as int?) ?? 0;

    // Data
    final rows = await db.query(
      'places',
      where: whereStr,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'avg_rating DESC, id ASC',
      limit: limit,
      offset: offset,
    );

    return {
      'places': await _toJsonList(rows),
      'total': total,
    };
  }

  /// Single place by id.
  Future<Map<String, dynamic>?> getPlace(String id) async {
    final db = await database;
    final rows = await db.query('places', where: 'id = ?', whereArgs: [int.tryParse(id) ?? 0]);
    if (rows.isEmpty) return null;
    final imgs = await _imagesFor(rows.first['id'] as int);
    return _rowToJson(rows.first, imgs);
  }

  /// Recommendations based on interest categories.
  Future<List<Map<String, dynamic>>> getRecommendations(
      List<String> interests, {int limit = 10}) async {
    if (interests.isEmpty) return getFeatured(limit: limit);
    final db = await database;
    final placeholders = interests.map((_) => 'LOWER(category) = LOWER(?)').join(' OR ');
    final rows = await db.rawQuery(
        'SELECT * FROM places WHERE ($placeholders) ORDER BY avg_rating DESC LIMIT ?',
        [...interests, limit]);
    return _toJsonList(rows);
  }

  /// All distinct categories.
  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT category FROM places WHERE category != "" ORDER BY category');
    return rows.map((r) => r['category'] as String).toList();
  }

  /// All distinct governorates.
  Future<List<String>> getGovernorates() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT governorate FROM places WHERE governorate != "" ORDER BY governorate');
    return rows.map((r) => r['governorate'] as String).toList();
  }
}
