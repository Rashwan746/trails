import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/profile_service.dart';
import '../services/cache_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _profileService = ProfileService();
  final _cacheService   = CacheService();

  String _cacheSize = '...';
  bool   _clearing  = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      final bytes = await _cacheService.getCacheSize();
      final mb    = (bytes / (1024 * 1024));
      if (mounted) {
        setState(() => _cacheSize = mb < 1
            ? '${bytes ~/ 1024} KB'
            : '${mb.toStringAsFixed(0)} MB');
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '—');
    }
  }

  Future<void> _toggle(
      BuildContext ctx, User user, String field, bool val) async {
    try {
      final u = await _profileService.updateSettings(
        emailUpdates:        field == 'email'    ? val : null,
        tripReminders:       field == 'trip'     ? val : null,
        darkMode:            field == 'dark'     ? val : null,
      );
      if (mounted) ctx.read<AuthProvider>().updateUser(u);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Cache',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This will clear all cached data. You may need to reload content.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
                style: GoogleFonts.poppins(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      await _cacheService.clearAll();
      if (mounted) {
        setState(() { _cacheSize = '0 MB'; _clearing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared',
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('App Settings',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Notifications card ────────────────────────────────────
            _card([
              _switchRow(
                icon: Icons.email_outlined,
                iconBg: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                label: 'Email Updates',
                value: user.emailUpdates,
                onChanged: (v) => _toggle(context, user, 'email', v),
              ),
              _divider(),
              _switchRow(
                icon: Icons.calendar_today_outlined,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                label: 'Trip Reminders',
                value: user.tripReminders,
                onChanged: (v) => _toggle(context, user, 'trip', v),
              ),
            ]),

            const SizedBox(height: 24),

            // ── DISPLAY ───────────────────────────────────────────────
            _sectionLabel('DISPLAY'),
            const SizedBox(height: 10),
            _card([
              _switchRow(
                icon: Icons.dark_mode_outlined,
                iconBg: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF4C1D95),
                label: 'Dark Mode',
                value: user.darkMode,
                onChanged: (v) => _toggle(context, user, 'dark', v),
              ),
            ]),

            const SizedBox(height: 24),

            // ── DATA & PRIVACY ────────────────────────────────────────
            _sectionLabel('DATA & PRIVACY'),
            const SizedBox(height: 10),
            _card([
              _tapRow(
                icon: Icons.delete_outline_rounded,
                iconBg: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFDC2626),
                label: 'Clear Cache',
                trailing: _clearing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : Text(_cacheSize,
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary, fontSize: 13)),
                onTap: _clearing ? null : _clearCache,
              ),
            ]),

            const SizedBox(height: 28),

            // ── Dark Mode promo banner ─────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Background image (Egyptian temple)
                  SizedBox(
                    width: double.infinity,
                    height: 170,
                    child: Image.network(
                      'https://images.unsplash.com/photo-1568322445389-f64ac2515020?w=800&q=80',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E1B4B),
                        height: 170,
                      ),
                    ),
                  ),
                  // Dark gradient overlay
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.black.withOpacity(0.72),
                        ],
                      ),
                    ),
                  ),
                  // Text overlay
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Experience Egypt in Dark Mode',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Our maps and guides look stunning in the dark.',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.primary, letterSpacing: 0.8));
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16,
          color: Color(0xFFF3F4F6));

  Widget _switchRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF3B82F6),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1D5DB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _tapRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            trailing,
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}
