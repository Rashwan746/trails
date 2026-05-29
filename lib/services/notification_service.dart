import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../constants/app_colors.dart';

/// Notification model
class AppNotification {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime sentAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.sentAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      sentAt: DateTime.tryParse(json['sent_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Service for managing device FCM token and notification history.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _api = ApiService();
  static const _tokenKey = 'fcm_token';

  /// Register FCM token with backend.
  /// Call this after Firebase.initializeApp() and getToken().
  Future<void> registerToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_tokenKey);

      // Only send if token changed
      if (stored != token) {
        await _api.post('/notifications/token', {
          'fcm_token': token,
          'platform': 'android',
        });
        await prefs.setString(_tokenKey, token);
      }
    } catch (_) {
      // Non-critical — continue silently
    }
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    try {
      await _api.delete('/notifications/token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  /// Get notification history from backend
  Future<List<AppNotification>> getNotifications() async {
    try {
      final res = await _api.get('/notifications');
      return (res['data'] as List)
          .map((n) => AppNotification.fromJson(n))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Mark all notifications as read
  Future<void> markAllRead() async {
    try {
      await _api.put('/notifications/read', {});
    } catch (_) {}
  }

  /// Show an in-app notification banner (no Firebase needed)
  static void showBanner(BuildContext context, String title, String body) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(body, style: const TextStyle(fontSize: 13)),
          ],
        ),
        leading: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
        backgroundColor: Colors.white,
        elevation: 4,
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      try {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      } catch (_) {}
    });
  }
}
