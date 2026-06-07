import 'place_model.dart';

class TripItem {
  final String id;
  final Place? place;
  final String placeId;
  final int day;
  final int order;
  final String note;
  final int visitDuration; // minutes

  TripItem({
    required this.id,
    this.place,
    required this.placeId,
    required this.day,
    required this.order,
    this.note = '',
    this.visitDuration = 120,
  });

  factory TripItem.fromJson(Map<String, dynamic> json) {
    Place? place;
    String placeId = '';
    if (json['place'] is Map) {
      place = Place.fromJson(json['place']);
      placeId = place.id;
    } else if (json['place'] is String) {
      placeId = json['place'];
    }
    return TripItem(
      id: json['_id'] ?? '',
      place: place,
      placeId: placeId,
      day: json['day'] ?? 1,
      order: json['order'] ?? 0,
      note: json['note'] ?? '',
      visitDuration: json['visit_duration'] ?? 120,
    );
  }
}

class Trip {
  final String id;
  final String title;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int durationDays;
  final List<TripItem> items;
  final bool isPublic;
  final String coverImage;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.title,
    this.description = '',
    this.startDate,
    this.endDate,
    required this.durationDays,
    this.items = const [],
    this.isPublic = false,
    this.coverImage = '',
    required this.createdAt,
  });

  List<TripItem> itemsForDay(int day) =>
      items.where((i) => i.day == day).toList()..sort((a, b) => a.order.compareTo(b.order));

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['_id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
        durationDays: json['duration_days'] ?? 1,
        items: (json['items'] as List? ?? []).map((i) => TripItem.fromJson(i)).toList(),
        isPublic: json['is_public'] ?? false,
        coverImage: json['cover_image'] ?? '',
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}
