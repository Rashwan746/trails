import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    _user = await _authService.getStoredUser();
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String password,
    String? phone,
    String? email,
  }) async {
    _setLoading(true);
    try {
      final res = await _authService.register(
        fullName: fullName, password: password, phone: phone, email: email);
      return res;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyOtp(String userId, String otp) async {
    _setLoading(true);
    try {
      _user = await _authService.verifyOtp(userId: userId, otp: otp);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Verifies OTP and stores the user but does NOT call notifyListeners().
  /// Use [activateLogin] afterwards to trigger navigation.
  Future<void> verifyOtpSilent(String userId, String otp) async {
    _setLoading(true);
    try {
      _user = await _authService.verifyOtp(userId: userId, otp: otp);
      // intentionally no notifyListeners here
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Triggers navigation by notifying listeners that user is now set.
  void activateLogin() => notifyListeners();

  Future<void> login(String identifier, String password) async {
    _setLoading(true);
    try {
      _user = await _authService.login(identifier: identifier, password: password);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> resendOtp({String? phone, String? email}) async {
    _setLoading(true);
    try {
      return await _authService.resendOtp(phone: phone, email: email);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    _setLoading(true);
    try {
      return await _authService.forgotPassword(identifier);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword({
    required String userId,
    required String otp,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      _user = await _authService.resetPassword(
          userId: userId, otp: otp, newPassword: newPassword);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    notifyListeners();
  }
}
