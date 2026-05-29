import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String password,
    String? phone,
    String? email,
  }) async {
    final body = {
      'full_name': fullName,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    };
    return await _api.post('/auth/register', body);
  }

  Future<User> verifyOtp({required String userId, required String otp}) async {
    final res = await _api.post('/auth/verify-otp', {'user_id': userId, 'otp': otp});
    await _saveSession(res);
    return User.fromJson(res['user']);
  }

  Future<User> login({required String identifier, required String password}) async {
    final res = await _api.post('/auth/login', {'identifier': identifier, 'password': password});
    await _saveSession(res);
    return User.fromJson(res['user']);
  }

  Future<Map<String, dynamic>> resendOtp({String? phone, String? email}) async {
    final body = <String, dynamic>{};
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (email != null && email.isNotEmpty) body['email'] = email;
    return await _api.post('/auth/resend-otp', body);
  }

  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    return await _api.post('/auth/forgot-password', {'identifier': identifier});
  }

  Future<User> resetPassword({
    required String userId,
    required String otp,
    required String newPassword,
  }) async {
    final res = await _api.post('/auth/reset-password', {
      'user_id': userId,
      'otp': otp,
      'new_password': newPassword,
    });
    await _saveSession(res);
    return User.fromJson(res['user']);
  }

  Future<void> _saveSession(Map<String, dynamic> res) async {
    await _api.saveToken(res['token']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(res['user']));
  }

  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData == null) return null;
    return User.fromJson(jsonDecode(userData));
  }

  Future<void> logout() async {
    await _api.clearToken();
  }

  bool get isLoggedIn => _api.isAuthenticated;
}
