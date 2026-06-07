import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/profile_service.dart';
import '../services/analytics_service.dart';
import 'app_settings_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _analytics      = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _analytics.screenView('profile');
  }

  // ── Language ───────────────────────────────────────────────────────────────
  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        final isAr = context.read<LocaleProvider>().isArabic;
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Language',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _langOption('English (US)', !isAr, () async {
                  await context.read<LocaleProvider>().setLocale('en');
                  try {
                    final u = await _profileService.updateSettings(language: 'en');
                    if (mounted) context.read<AuthProvider>().updateUser(u);
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                }),
                const Divider(height: 1),
                _langOption('العربية', isAr, () async {
                  await context.read<LocaleProvider>().setLocale('ar');
                  try {
                    final u = await _profileService.updateSettings(language: 'ar');
                    if (mounted) context.read<AuthProvider>().updateUser(u);
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                }),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _langOption(String label, bool selected, VoidCallback onTap) {
    return ListTile(
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.primary : AppColors.textPrimary)),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }

  // ── Currency ───────────────────────────────────────────────────────────────
  void _showCurrencyDialog() {
    final currencies = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED'];
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currency',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...currencies.map((c) {
              final isSel = user?.currency == c;
              return Column(children: [
                ListTile(
                  title: Text(c,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                          color: isSel ? AppColors.primary : AppColors.textPrimary)),
                  trailing: isSel
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () async {
                    try {
                      final u = await _profileService.updateSettings(currency: c);
                      if (mounted) context.read<AuthProvider>().updateUser(u);
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
              ]);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Interests ──────────────────────────────────────────────────────────────
  void _showInterestsSheet() async {
    final allInterests = await _profileService.getAllInterests();
    final user = context.read<AuthProvider>().user!;
    final selected = Set<String>.from(user.interests);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Interests',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: allInterests.map((interest) {
                  final isSel = selected.contains(interest);
                  return GestureDetector(
                    onTap: () => setSt(() =>
                        isSel ? selected.remove(interest) : selected.add(interest)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSel ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(interest,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final u = await _profileService.updateInterests(selected.toList());
                      if (mounted) context.read<AuthProvider>().updateUser(u);
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Save',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<void> _toggleNotifications(bool val) async {
    try {
      final u = await _profileService.updateSettings(notificationsEnabled: val);
      if (mounted) context.read<AuthProvider>().updateUser(u);
    } catch (_) {}
  }

  // ── Location ───────────────────────────────────────────────────────────────
  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        String selected = 'While Using';
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location Access',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Allow Discover Egypt to access your location',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                for (final opt in ['Always', 'While Using', 'Never'])
                  Column(children: [
                    ListTile(
                      title: Text(opt,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: selected == opt
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected == opt
                                  ? AppColors.primary
                                  : AppColors.textPrimary)),
                      trailing: selected == opt
                          ? const Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => setSt(() => selected = opt),
                    ),
                    const Divider(height: 1),
                  ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Save',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Help & Support ─────────────────────────────────────────────────────────
  void _showHelpSheet() {
    final faqs = [
      ('How do I add a review?', 'Open any place, scroll to Reviews, and tap "Write a Review".'),
      ('How do I save a place?', 'Tap the heart icon on any place card or in the place details.'),
      ('How do I change my language?', 'Go to Profile → Preferences → Language.'),
      ('Can I use the app offline?', 'Yes! Previously viewed places are cached for offline use.'),
      ('How do I report an issue?', 'Email us at support@discoveregypt.com'),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Help & Support',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  itemCount: faqs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) => ExpansionTile(
                    title: Text(faqs[i].$1,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    iconColor: AppColors.primary,
                    collapsedIconColor: AppColors.textLight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(faqs[i].$2,
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.textSecondary,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit profile ────────────────────────────────────────────────────────────
  void _showEditProfileSheet() {
    final user = context.read<AuthProvider>().user!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditProfilePage(
          user: user,
          profileService: _profileService,
          onSaved: (User u) => context.read<AuthProvider>().updateUser(u),
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out',
                style: GoogleFonts.poppins(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user;
    final isAr  = context.watch<LocaleProvider>().isArabic;
    final botPad = MediaQuery.of(context).padding.bottom;

    if (user == null) return _buildGuestView(context);

    final memberYear = user.memberSince.year;
    final city = user.city.isNotEmpty ? user.city : 'Egypt';
    final interests = user.interests.isEmpty ? 'None set' : user.interests.take(2).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              color: AppColors.primary, size: 30),
          onPressed: () {},
        ),
        title: Text('Profile',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _showEditProfileSheet,
            child: Text('Edit',
                style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: botPad + 80),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Avatar ────────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 16)],
                  ),
                  child: ClipOval(
                    child: user.avatarUrl.isNotEmpty
                        ? Image.network(user.avatarUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarFallback(user.initials))
                        : _avatarFallback(user.initials),
                  ),
                ),
                Positioned(
                  bottom: 2, right: 2,
                  child: GestureDetector(
                    onTap: _showEditProfileSheet,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Name ──────────────────────────────────────────────────
            Text(user.fullName,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Exploring $city  •  Member since $memberYear',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 13)),

            const SizedBox(height: 12),

            // ── Badge ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Travel Enthusiast',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── PREFERENCES ───────────────────────────────────────────
            _sectionHeader('PREFERENCES'),
            _settingsCard([
              _row(
                iconBg: const Color(0xFF3B82F6),
                icon: Icons.language_rounded,
                label: 'Language',
                value: isAr ? 'العربية' : 'English (US)',
                onTap: _showLanguageDialog,
              ),
              _row(
                iconBg: const Color(0xFF10B981),
                icon: Icons.currency_pound_rounded,
                label: 'Currency',
                value: user.currency,
                onTap: _showCurrencyDialog,
              ),
              _row(
                iconBg: const Color(0xFFF59E0B),
                icon: Icons.apps_rounded,
                label: 'Interests',
                value: interests,
                onTap: _showInterestsSheet,
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ── ACCOUNT SETTINGS ──────────────────────────────────────
            _sectionHeader('ACCOUNT SETTINGS'),
            _settingsCard([
              _switchRow(
                iconBg: const Color(0xFF8B5CF6),
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                value: user.notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
              _row(
                iconBg: const Color(0xFF0EA5E9),
                icon: Icons.near_me_rounded,
                label: 'Location Access',
                value: 'While Using',
                onTap: _showLocationSheet,
              ),
              _row(
                iconBg: const Color(0xFF6B7280),
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                value: '',
                onTap: _showHelpSheet,
              ),
              _row(
                iconBg: const Color(0xFF1D4ED8),
                icon: Icons.settings_outlined,
                label: 'App Settings',
                value: '',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AppSettingsScreen())),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 30),

            // ── Log Out ───────────────────────────────────────────────
            GestureDetector(
              onTap: _logout,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('Log Out',
                      style: GoogleFonts.poppins(
                          color: Colors.red.shade400,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _avatarFallback(String initials) {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(initials,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 1.0)),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _row({
    required Color iconBg,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(18))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            if (value.isNotEmpty)
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required Color iconBg,
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14.5, fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1D5DB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── Guest view ─────────────────────────────────────────────────────────────
  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.person_outline_rounded,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Join Discover Egypt',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('Create an account to save favorites,\nwrite reviews, and more.',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('Create Account',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AuthScreen())),
                child: Text('Already have an account? Log In',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary, fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile — full-screen page
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfilePage extends StatefulWidget {
  final User user;
  final ProfileService profileService;
  final void Function(User) onSaved;

  const _EditProfilePage({
    required this.user,
    required this.profileService,
    required this.onSaved,
  });

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.user.fullName);
    _emailCtrl = TextEditingController(text: widget.user.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _cityCtrl  = TextEditingController(text: widget.user.city);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final u = await widget.profileService.updateProfile(
        fullName: _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        city:     _cityCtrl.text.trim(),
      );
      widget.onSaved(u);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              color: AppColors.primary, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 28),

            // ── Avatar ────────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  ),
                  child: ClipOval(
                    child: widget.user.avatarUrl.isNotEmpty
                        ? Image.network(widget.user.avatarUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarFallback())
                        : _avatarFallback(),
                  ),
                ),
                Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () {},
              child: Text('Change Profile Photo',
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),

            const SizedBox(height: 24),

            // ── Fields ────────────────────────────────────────────────
            _label('FULL NAME'),
            const SizedBox(height: 6),
            _field(_nameCtrl, 'Ahmed Ezzat',
                keyboardType: TextInputType.name),

            const SizedBox(height: 18),
            _label('EMAIL ADDRESS'),
            const SizedBox(height: 6),
            _field(_emailCtrl, 'example@email.com',
                keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 18),
            _label('PHONE NUMBER'),
            const SizedBox(height: 6),
            _field(_phoneCtrl, '+20 100 000 0000',
                keyboardType: TextInputType.phone),

            const SizedBox(height: 18),
            _label('CITY'),
            const SizedBox(height: 6),
            _field(_cityCtrl, 'Cairo, Egypt',
                suffix: const Icon(Icons.location_on_outlined,
                    color: AppColors.textLight, size: 20)),

            const SizedBox(height: 36),

            // ── Save button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text('Save Changes',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(widget.user.initials,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 30,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _label(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary, letterSpacing: 0.8)),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            color: AppColors.textLight, fontSize: 15),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
