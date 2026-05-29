import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';

class ProfileService {
  final ApiService _api = ApiService();

  Future<User> getProfile() async {
    final res = await _api.get('/profile/me');
    final user = User.fromJson(res['data']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(res['data']));
    return user;
  }

  Future<User> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? city,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (city != null) body['city'] = city;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final res = await _api.put('/profile/me', body);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(res['data']));
    return User.fromJson(res['data']);
  }

  Future<User> updateSettings({
    String? language,
    String? currency,
    bool? darkMode,
    bool? notificationsEnabled,
    bool? locationAccess,
    bool? emailUpdates,
    bool? tripReminders,
  }) async {
    final body = <String, dynamic>{};
    if (language != null) body['language'] = language;
    if (currency != null) body['currency'] = currency;
    if (darkMode != null) body['dark_mode'] = darkMode;
    if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled;
    if (locationAccess != null) body['location_access'] = locationAccess;
    if (emailUpdates != null) body['email_updates'] = emailUpdates;
    if (tripReminders != null) body['trip_reminders'] = tripReminders;

    final res = await _api.put('/profile/settings', body);
    return User.fromJson(res['data']);
  }

  Future<User> updateInterests(List<String> interests) async {
    final res = await _api.put('/profile/interests', {'interests': interests});
    return User.fromJson(res['data']);
  }

  Future<List<String>> getAllInterests() async {
    final res = await _api.get('/profile/interests/all');
    return List<String>.from(res['data']);
  }
}
