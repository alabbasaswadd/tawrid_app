import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// مقياس نصّي واحد — المصدر الوحيد للخطوط، مطابق للتدرّج الطباعي في Figma
// (الهوية · الخطوط والمقاسات — خط Tajawal):
//   عنوان رئيسي  Bold 22 / 32      → displayMedium
//   عنوان قسم    Bold 18 / 26      → titleLarge
//   عنوان عنصر   Medium 16 / 24    → titleMedium
//   نص أساسي     Regular 14 / 22   → bodyMedium
//   نص مساعد     Regular 12 / 18   → bodySmall
//   بيانات ثانوية Regular 11 / 16  → labelSmall
//   نص زر        Medium 15 / 20    → labelLarge
//   سعر وأرقام   Bold 16 / 22      → AppTypography.price
// ألوان النصوص تُشتقّ من ColorScheme فتتكيّف تلقائياً مع الدارك مود.
abstract final class AppTypography {
  static TextStyle _tajawal({
    required double size,
    required FontWeight weight,
    required double lineHeight,
    required Color color,
  }) => GoogleFonts.tajawal(
    fontSize: size,
    fontWeight: weight,
    height: lineHeight / size,
    color: color,
  );

  // «سعر وأرقام» — Tajawal Bold 16/22. يُستهلك عبر context.priceStyle.
  static TextStyle price(Color color) =>
      _tajawal(size: 16, weight: FontWeight.w700, lineHeight: 22, color: color);

  static TextTheme textTheme(ColorScheme scheme) {
    final primary = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
    final base = GoogleFonts.tajawalTextTheme(const TextTheme());

    return base.copyWith(
      // مشتقّان أكبر من المقياس — لشاشات البداية والعناوين الضخمة فقط.
      displayLarge: _tajawal(
        size: 26,
        weight: FontWeight.w700,
        lineHeight: 36,
        color: primary,
      ),
      displayMedium: _tajawal(
        size: 22,
        weight: FontWeight.w700,
        lineHeight: 32,
        color: primary,
      ),
      headlineSmall: _tajawal(
        size: 20,
        weight: FontWeight.w700,
        lineHeight: 28,
        color: primary,
      ),
      titleLarge: _tajawal(
        size: 18,
        weight: FontWeight.w700,
        lineHeight: 26,
        color: primary,
      ),
      titleMedium: _tajawal(
        size: 16,
        weight: FontWeight.w500,
        lineHeight: 24,
        color: primary,
      ),
      titleSmall: _tajawal(
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 20,
        color: primary,
      ),
      bodyLarge: _tajawal(
        size: 15,
        weight: FontWeight.w400,
        lineHeight: 24,
        color: primary,
      ),
      bodyMedium: _tajawal(
        size: 14,
        weight: FontWeight.w400,
        lineHeight: 22,
        color: primary,
      ),
      bodySmall: _tajawal(
        size: 12,
        weight: FontWeight.w400,
        lineHeight: 18,
        color: secondary,
      ),
      labelLarge: _tajawal(
        size: 15,
        weight: FontWeight.w500,
        lineHeight: 20,
        color: primary,
      ),
      labelMedium: _tajawal(
        size: 12,
        weight: FontWeight.w500,
        lineHeight: 18,
        color: secondary,
      ),
      labelSmall: _tajawal(
        size: 11,
        weight: FontWeight.w400,
        lineHeight: 16,
        color: secondary,
      ),
    );
  }
}
