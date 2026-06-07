import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? body;

  ApiException(this.message, [this.statusCode, this.body]);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    if (params != null && params.isNotEmpty) {
      return uri.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }

  dynamic _parseResponse(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = body['message'] ?? 'Unknown error occurred';
    throw ApiException(message, response.statusCode,
        Map<String, dynamic>.from(body as Map));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    await loadToken();
    final response = await http
        .get(_uri(path, params), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    return _parseResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    await loadToken();
    final response = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(AppConfig.connectTimeout);
    return _parseResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    await loadToken();
    final response = await http
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(AppConfig.connectTimeout);
    return _parseResponse(response);
  }

  Future<dynamic> delete(String path) async {
    await loadToken();
    final response = await http
        .delete(_uri(path), headers: _headers)
        .timeout(AppConfig.connectTimeout);
    return _parseResponse(response);
  }
}
