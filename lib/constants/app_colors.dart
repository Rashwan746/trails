import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFE8750A);      // Egypt orange (matches design)
  static const Color primaryDark = Color(0xFFC45E00);
  static const Color primaryLight = Color(0xFFFFF0E0); // Light orange tint
  static const Color secondary = Color(0xFF1A1A2E);    // Dark navy
  static const Color accent = Color(0xFFF09040);       // Lighter orange
  static const Color background = Color(0xFFF8F8F8);   // Off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color starColor = Color(0xFFFBBF24);
  static const Color shimmerBase = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF9FAFB);

  // Category colors
  static const Map<String, Color> categoryColors = {
    'historical': Color(0xFFE8750A),
    'beach': Color(0xFF0891B2),
    'desert': Color(0xFFE8750A),
    'museum': Color(0xFF7C3AED),
    'religious': Color(0xFF059669),
    'nature': Color(0xFF16A34A),
    'market': Color(0xFFDC2626),
    'cruise':     Color(0xFF2563EB),
    'restaurant': Color(0xFFE11D48),
    'hotel':      Color(0xFF0D9488),
  };
}
