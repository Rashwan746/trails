import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';

/// Automatically shows/hides based on network connectivity.
/// Matches the app's existing UI design.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final _connectivity = ConnectivityService();
  bool _isOffline = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _heightAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);

    _checkConnectivity();
    _connectivity.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;
      setState(() => _isOffline = !isOnline);
      if (_isOffline) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivity.isOnline();
    if (!mounted) return;
    setState(() => _isOffline = !isOnline);
    if (_isOffline) _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _heightAnim,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFEA580C), // orange-600 — matches app warning style
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                "You're offline — showing cached data",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
