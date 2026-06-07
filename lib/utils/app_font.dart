import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

/// Global locale flag — set via [setAppLocale] on every locale change.
bool _isArabic = false;

void setAppLocale(String languageCode) {
  _isArabic = languageCode == 'ar';
}

bool get isAppArabic => _isArabic;

/// Returns a Cairo TextStyle when Arabic, Poppins when English.
/// Drop-in replacement for GoogleFonts.poppins(…).
TextStyle appFont({
  double?           fontSize,
  FontWeight?       fontWeight,
  Color?            color,
  double?           height,
  double?           letterSpacing,
  TextDecoration?   decoration,
  Color?            decorationColor,
  double?           wordSpacing,
  FontStyle?        fontStyle,
  TextBaseline?     textBaseline,
}) {
  if (_isArabic) {
    return GoogleFonts.cairo(
      fontSize:         fontSize,
      fontWeight:       fontWeight,
      color:            color,
      height:           height,
      letterSpacing:    letterSpacing,
      decoration:       decoration,
      decorationColor:  decorationColor,
      wordSpacing:      wordSpacing,
      fontStyle:        fontStyle,
      textBaseline:     textBaseline,
    );
  }
  return GoogleFonts.poppins(
    fontSize:         fontSize,
    fontWeight:       fontWeight,
    color:            color,
    height:           height,
    letterSpacing:    letterSpacing,
    decoration:       decoration,
    decorationColor:  decorationColor,
    wordSpacing:      wordSpacing,
    fontStyle:        fontStyle,
    textBaseline:     textBaseline,
  );
}

/// TextTheme: Cairo for Arabic, Poppins for English.
TextTheme appTextTheme() =>
    _isArabic ? GoogleFonts.cairoTextTheme() : GoogleFonts.poppinsTextTheme();
