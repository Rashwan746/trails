class PlaceLocation {
  final List<double> coordinates; // [lng, lat]
  final String address;

  PlaceLocation({required this.coordinates, required this.address});

  double get longitude => coordinates.isNotEmpty ? coordinates[0] : 0;
  double get latitude => coordinates.length > 1 ? coordinates[1] : 0;

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    final coords = (json['coordinates'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [0.0, 0.0];
    return PlaceLocation(
      coordinates: coords,
      address: json['address'] ?? '',
    );
  }
}

class AdmissionFee {
  final double egyptian;
  final double foreign;
  final String currency;

  AdmissionFee({required this.egyptian, required this.foreign, required this.currency});

  factory AdmissionFee.fromJson(Map<String, dynamic> json) => AdmissionFee(
        egyptian: (json['egyptian'] ?? 0).toDouble(),
        foreign: (json['foreign'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'EGP',
      );
}

class OpeningHours {
  final String open;
  final String close;
  final String days;

  OpeningHours({required this.open, required this.close, required this.days});

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        open: json['open'] ?? '08:00',
        close: json['close'] ?? '17:00',
        days: json['days'] ?? 'Daily',
      );
}

class RatingBreakdown {
  final int r1, r2, r3, r4, r5;

  RatingBreakdown({
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.r5,
  });

  factory RatingBreakdown.fromJson(Map<String, dynamic> json) => RatingBreakdown(
        r1: json['1'] ?? 0,
        r2: json['2'] ?? 0,
        r3: json['3'] ?? 0,
        r4: json['4'] ?? 0,
        r5: json['5'] ?? 0,
      );

  int get total => r1 + r2 + r3 + r4 + r5;
}

class Place {
  final String id;
  final Map<String, String> name;
  final Map<String, String> description;
  final String category;
  final String governorate;
  final PlaceLocation location;
  final List<String> images;
  final String coverImage;
  final AdmissionFee admissionFee;
  final OpeningHours openingHours;
  final List<String> tags;
  final bool isFeatured;
  final double avgRating;
  final int reviewCount;
  final RatingBreakdown ratingBreakdown;
  bool isFavorite;

  Place({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.governorate,
    required this.location,
    required this.images,
    required this.coverImage,
    required this.admissionFee,
    required this.openingHours,
    required this.tags,
    required this.isFeatured,
    required this.avgRating,
    required this.reviewCount,
    required this.ratingBreakdown,
    this.isFavorite = false,
  });

  String getName(String locale) => name[locale] ?? name['en'] ?? '';
  String getDescription(String locale) => description[locale] ?? description['en'] ?? '';

  String get displayImage => coverImage.isNotEmpty ? coverImage : (images.isNotEmpty ? images[0] : '');

  static String _safeUrl(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '';
    // Already an absolute URL
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    // Relative path — cannot resolve without knowing server; return empty so
    // the image widget shows the fallback placeholder instead of a 404.
    return '';
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    final rawImages = List<dynamic>.from(json['images'] ?? []);
    final images = rawImages.map((u) => _safeUrl(u)).where((u) => u.isNotEmpty).toList();
    final coverImage = _safeUrl(json['cover_image']);
    return Place(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: Map<String, String>.from(json['name'] ?? {'en': '', 'ar': ''}),
      description: Map<String, String>.from(
          json['description'] ?? {'en': '', 'ar': ''}),
      category: json['category'] ?? '',
      governorate: json['governorate'] ?? '',
      location: PlaceLocation.fromJson(json['location'] ?? {}),
      images: images,
      coverImage: coverImage.isNotEmpty ? coverImage : (images.isNotEmpty ? images[0] : ''),
      admissionFee: AdmissionFee.fromJson(json['admission_fee'] ?? {}),
      openingHours: OpeningHours.fromJson(json['opening_hours'] ?? {}),
      tags: List<String>.from(json['tags'] ?? []),
      isFeatured: json['is_featured'] ?? false,
      avgRating: (json['avg_rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      ratingBreakdown: RatingBreakdown.fromJson(json['rating_breakdown'] ?? {}),
      isFavorite: json['is_favorite'] ?? false,
    );
  }
}
