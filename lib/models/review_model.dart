class ReviewUser {
  final String id;
  final String fullName;
  final String city;
  final String avatarUrl;
  final String? country;

  ReviewUser({required this.id, required this.fullName, this.city = '', this.avatarUrl = '', this.country});

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  factory ReviewUser.fromJson(Map<String, dynamic> json) => ReviewUser(
        id: json['_id'] ?? '',
        fullName: json['full_name'] ?? 'Anonymous',
        city: json['city'] ?? '',
        avatarUrl: json['avatar_url'] ?? '',
        country: json['country'],
      );
}

class Review {
  final String id;
  final String placeId;
  final ReviewUser user;
  final int stars;
  final String text;
  final List<String> images;
  final List<String> tags;
  int helpfulCount;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.placeId,
    required this.user,
    required this.stars,
    required this.text,
    this.images = const [],
    this.tags = const [],
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['_id'] ?? '',
        placeId: json['place'] ?? '',
        user: ReviewUser.fromJson(json['user'] is Map ? json['user'] : {'_id': '', 'full_name': 'Anonymous'}),
        stars: json['stars'] ?? 1,
        text: json['text'] ?? '',
        images: List<String>.from(json['images'] ?? []),
        tags: List<String>.from(json['tags'] ?? []),
        helpfulCount: json['helpful_count'] ?? 0,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}
