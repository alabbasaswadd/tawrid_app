import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// مقياس نصّي واحد — المصدر الوحيد للخطوط. ألوان النصوص تُشتقّ من ColorScheme
// (onSurface / onSurfaceVariant) فتتكيّف تلقائياً مع الدارك مود.
//
// الخط المعتمد: Cairo.
// تبديل العائلة لاحقاً يتم عبر _font + استبدال أسطر GoogleFonts فقط.
abstract final class AppTypography {
  static TextTheme _font(TextTheme base) => GoogleFonts.cairoTextTheme(base);

  static TextTheme textTheme(ColorScheme scheme) {
    final primary = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
    final base = _font(const TextTheme());

    return base.copyWith(
      displayLarge: GoogleFonts.cairo(fontSize: 30, fontWeight: FontWeight.w700, color: primary, height: 1.25),
      displayMedium: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w700, color: primary, height: 1.3),
      headlineSmall: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w600, color: primary, height: 1.3),
      titleLarge: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w600, color: primary, height: 1.35),
      titleMedium: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      titleSmall: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      bodyLarge: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodySmall: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w400, color: secondary, height: 1.5),
      labelLarge: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary),
      labelSmall: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600, color: secondary),
    );
  }
}
