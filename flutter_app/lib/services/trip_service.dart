import 'api_service.dart';
import '../models/trip_model.dart';

class TripService {
  final ApiService _api = ApiService();

  Future<List<Trip>> getTrips() async {
    final res = await _api.get('/trips');
    return (res['data'] as List).map((j) => Trip.fromJson(j)).toList();
  }

  Future<Trip> createTrip({
    required String title,
    required int durationDays,
    String description = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'duration_days': durationDays,
      'description': description,
    };
    if (startDate != null) body['start_date'] = startDate.toIso8601String();
    if (endDate != null) body['end_date'] = endDate.toIso8601String();

    final res = await _api.post('/trips', body);
    return Trip.fromJson(res['data']);
  }

  Future<Trip> getTrip(String id) async {
    final res = await _api.get('/trips/$id');
    return Trip.fromJson(res['data']);
  }

  Future<Trip> addPlaceToTrip({
    required String tripId,
    required String placeId,
    required int day,
    required int order,
    String note = '',
    int visitDuration = 120,
  }) async {
    final res = await _api.post('/trips/$tripId/items', {
      'place_id': placeId,
      'day': day,
      'order': order,
      'note': note,
      'visit_duration': visitDuration,
    });
    return Trip.fromJson(res['data']);
  }

  Future<void> deleteTrip(String id) async {
    await _api.delete('/trips/$id');
  }
}
