import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// مقياس نصّي واحد — المصدر الوحيد للخطوط. ألوان النصوص تُشتقّ من ColorScheme
// (onSurface / onSurfaceVariant) فتتكيّف تلقائياً مع الدارك مود.
//
// الخط المعتمد: IBM Plex Sans Arabic — رصين هادئ يليق بجمهور مثقّف.
// تبديل العائلة لاحقاً يتم عبر _font + استبدال أسطر GoogleFonts فقط.
abstract final class AppTypography {
  static TextTheme _font(TextTheme base) => GoogleFonts.ibmPlexSansArabicTextTheme(base);

  static TextTheme textTheme(ColorScheme scheme) {
    final primary = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
    final base = _font(const TextTheme());

    return base.copyWith(
      displayLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 30, fontWeight: FontWeight.w700, color: primary, height: 1.25),
      displayMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 24, fontWeight: FontWeight.w700, color: primary, height: 1.3),
      headlineSmall: GoogleFonts.ibmPlexSansArabic(fontSize: 20, fontWeight: FontWeight.w600, color: primary, height: 1.3),
      titleLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.w600, color: primary, height: 1.35),
      titleMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      titleSmall: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w600, color: primary, height: 1.4),
      bodyLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodySmall: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.w400, color: secondary, height: 1.5),
      labelLarge: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary),
      labelSmall: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w600, color: secondary),
    );
  }
}
