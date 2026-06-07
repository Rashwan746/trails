import 'dart:async';
import 'dart:convert';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Analytics event types
class AnalyticsEvent {
  static const String appOpen = 'app_open';
  static const String screenView = 'screen_view';
  static const String placeView = 'place_view';
  static const String placeShare = 'place_share';
  static const String searchPerformed = 'search_performed';
  static const String favoriteToggled = 'favorite_toggled';
  static const String reviewSubmitted = 'review_submitted';
  static const String tripCreated = 'trip_created';
  static const String chatMessage = 'chat_message';
  static const String mapOpened = 'map_opened';
  static const String locationGranted = 'location_granted';
}

/// Analytics service — batches events and flushes them periodically.
/// Falls back gracefully when offline.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final _api = ApiService();
  final _connectivity = ConnectivityService();

  static const _queueKey = 'analytics_queue';
  static const _batchSize = 20;
  static const _flushInterval = Duration(minutes: 2);

  Timer? _flushTimer;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush(); // flush on dispose
  }

  /// Track a single event
  Future<void> track(String eventType, {Map<String, dynamic>? data}) async {
    final event = {
      'event_type': eventType,
      'event_data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add to local queue
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(raw);
    queue.add(event);

    // Keep queue bounded
    final bounded = queue.length > 200 ? queue.sublist(queue.length - 200) : queue;
    await prefs.setString(_queueKey, jsonEncode(bounded));

    // Flush immediately if batch is full
    if (bounded.length >= _batchSize) {
      _flush();
    }
  }

  /// Track screen view
  Future<void> screenView(String screenName) async {
    await track(AnalyticsEvent.screenView, data: {'screen': screenName});
  }

  /// Track place view
  Future<void> placeView(String placeId, String placeName) async {
    await track(AnalyticsEvent.placeView, data: {
      'place_id': placeId,
      'place_name': placeName,
    });
  }

  /// Flush queued events to backend
  Future<void> _flush() async {
    try {
      final isOnline = await _connectivity.isOnline();
      if (!isOnline) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey) ?? '[]';
      final List<dynamic> queue = jsonDecode(raw);
      if (queue.isEmpty) return;

      // Take up to batchSize events
      final batch = queue.take(_batchSize).toList();

      await _api.post('/analytics/batch', {'events': batch});

      // Remove sent events from queue
      final remaining = queue.skip(batch.length).toList();
      await prefs.setString(_queueKey, jsonEncode(remaining));
    } catch (_) {
      // Silent fail — events stay in queue for next flush
    }
  }

  /// Force flush (call on logout, app pause, etc.)
  Future<void> flush() => _flush();
}
