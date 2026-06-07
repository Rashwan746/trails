import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/trip_model.dart';
import '../models/place_model.dart';
import '../services/trip_service.dart';
import '../services/places_service.dart';
import 'overview_screen.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final _tripService = TripService();
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trips = await _tripService.getTrips();
      setState(() => _trips = trips);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTrip() async {
    final result = await showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CreateTripSheet(),
    );
    if (result != null) {
      await _load();
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => _TripDetailScreen(trip: result)));
      }
    }
  }

  Future<void> _deleteTrip(String id) async {
    try {
      await _tripService.deleteTrip(id);
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Trip Planner', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTrip,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Trip', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _trips.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _trips.length,
                    itemBuilder: (_, i) => _TripCard(
                      trip: _trips[i],
                      onTap: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => _TripDetailScreen(trip: _trips[i])));
                        _load();
                      },
                      onDelete: () => _deleteTrip(_trips[i].id),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 20),
          Text('No trips planned yet',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Create your first Egypt itinerary!',
              style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createTrip,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Plan a Trip', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripCard({required this.trip, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('🗺️', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${trip.durationDays} day${trip.durationDays > 1 ? 's' : ''} • ${trip.items.length} places',
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
            if (trip.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trip.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (trip.startDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.startDate!.day}/${trip.startDate!.month}/${trip.startDate!.year}',
                    style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripDetailScreen extends StatefulWidget {
  final Trip trip;
  const _TripDetailScreen({required this.trip});

  @override
  State<_TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<_TripDetailScreen> {
  final _tripService = TripService();
  final _placesService = PlacesService();
  late Trip _trip;
  int _currentDay = 1;

  @override
  void initState() { super.initState(); _trip = widget.trip; }

  Future<void> _addPlace() async {
    final res = await _placesService.getPlaces(limit: 20);
    final places = res['places'] as List<Place>;

    if (!mounted) return;
    final place = await showDialog<Place>(
      context: context,
      builder: (_) => _PlacePickerDialog(places: places),
    );
    if (place == null) return;

    try {
      final updated = await _tripService.addPlaceToTrip(
        tripId: _trip.id,
        placeId: place.id,
        day: _currentDay,
        order: _trip.itemsForDay(_currentDay).length,
      );
      setState(() => _trip = updated);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_trip.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDayTabs(),
          Expanded(
            child: _buildDayContent(_currentDay),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlace,
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: Text('Add Place', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDayTabs() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _trip.durationDays,
        itemBuilder: (_, i) {
          final day = i + 1;
          final isSelected = day == _currentDay;
          return GestureDetector(
            onTap: () => setState(() => _currentDay = day),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Day $day',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayContent(int day) {
    final items = _trip.itemsForDay(day);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No places for Day $day',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Tap "Add Place" to plan your day',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.place?.getName('en') ?? 'Unknown',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(item.place?.governorate ?? '',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Text('~${item.visitDuration} min visit',
                        style: GoogleFonts.poppins(
                            color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
              if (item.place != null)
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => OverviewScreen(place: item.place!))),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlacePickerDialog extends StatelessWidget {
  final List<Place> places;
  const _PlacePickerDialog({required this.places});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select a Place', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: places.length,
          itemBuilder: (_, i) => ListTile(
            leading: const Text('🏛️', style: TextStyle(fontSize: 24)),
            title: Text(places[i].getName('en'), style: GoogleFonts.poppins(fontSize: 13)),
            subtitle: Text(places[i].governorate,
                style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11)),
            onTap: () => Navigator.pop(context, places[i]),
          ),
        ),
      ),
    );
  }
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet();

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _tripService = TripService();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _days = 3;
  bool _loading = false;

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final trip = await _tripService.createTrip(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        durationDays: _days,
      );
      if (mounted) Navigator.pop(context, trip);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Create New Trip',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Trip Title',
              hintText: 'e.g. Cairo & Luxor Explorer',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Duration: $_days day${_days > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              Row(
                children: [
                  IconButton(
                    onPressed: () { if (_days > 1) setState(() => _days--); },
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.secondary),
                  ),
                  Text('$_days', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () { if (_days < 30) setState(() => _days++); },
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text('Create Trip',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
