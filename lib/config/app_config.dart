import 'package:flutter/foundation.dart';

class AppConfig {
  // Web: use localhost (preview browser)
  // Android emulator: use 10.0.2.2
  // Real device: use your machine's LAN IP
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    // 10.0.2.2 = Android emulator loopback to host
    // Use your machine's LAN IP for a real device (e.g. 192.168.1.9)
    const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
    if (useEmulator) return 'http://10.0.2.2:3000/api';
    return 'http://100.101.125.38:3000/api';
  }

  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const int defaultPageSize = 20;
}
