class User {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String city;
  final String avatarUrl;
  final bool isVerified;
  final String language;
  final String currency;
  final bool darkMode;
  final bool notificationsEnabled;
  final bool locationAccess;
  final bool emailUpdates;
  final bool tripReminders;
  final List<String> interests;
  final DateTime memberSince;

  User({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.city = '',
    this.avatarUrl = '',
    this.isVerified = false,
    this.language = 'en',
    this.currency = 'EGP',
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.locationAccess = false,
    this.emailUpdates = true,
    this.tripReminders = true,
    this.interests = const [],
    required this.memberSince,
  });

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        fullName: json['full_name']?.toString() ?? '',
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        city: json['city']?.toString() ?? '',
        avatarUrl: json['avatar_url']?.toString() ?? '',
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
        language: json['language']?.toString() ?? 'en',
        currency: json['currency']?.toString() ?? 'EGP',
        darkMode: json['dark_mode'] == true || json['dark_mode'] == 1,
        notificationsEnabled: json['notifications_enabled'] != false && json['notifications_enabled'] != 0,
        locationAccess: json['location_access'] == true || json['location_access'] == 1,
        emailUpdates: json['email_updates'] != false && json['email_updates'] != 0,
        tripReminders: json['trip_reminders'] != false && json['trip_reminders'] != 0,
        interests: (() {
          final raw = json['interests'];
          if (raw == null || raw == '') return <String>[];
          if (raw is List) return List<String>.from(raw);
          if (raw is String && raw.startsWith('[')) {
            try {
              final decoded = raw.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',');
              return decoded.where((s) => s.trim().isNotEmpty).toList();
            } catch (_) { return <String>[]; }
          }
          return <String>[];
        })(),
        memberSince: json['member_since'] != null
            ? DateTime.tryParse(json['member_since'].toString()) ?? DateTime.now()
            : json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
      );
}
