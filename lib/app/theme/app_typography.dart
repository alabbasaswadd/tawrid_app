import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// مقياس نصّي واحد — المصدر الوحيد للخطوط، مطابق للتدرّج الطباعي في Figma
// (الهوية · الخطوط والمقاسات — خط Tajawal) مع زيادة ٢px على كل مستوى:
//   عنوان رئيسي  Bold 24 / 34      → displayMedium
//   عنوان قسم    Bold 20 / 28      → titleLarge
//   عنوان عنصر (عنوان البطاقة)  Bold 19 / 27    → titleMedium
//   نص أساسي     Regular 16 / 24   → bodyMedium
//   نص مساعد     Regular 14 / 20   → bodySmall
//   بيانات ثانوية Regular 13 / 18  → labelSmall
//   نص زر        Medium 17 / 22    → labelLarge
//   سعر وأرقام   Bold 18 / 24      → AppTypography.price
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

  // «سعر وأرقام» — Tajawal Bold 18/24. يُستهلك عبر context.priceStyle.
  static TextStyle price(Color color) =>
      _tajawal(size: 18, weight: FontWeight.w700, lineHeight: 24, color: color);

  static TextTheme textTheme(ColorScheme scheme) {
    final primary = scheme.onSurface;
    final secondary = scheme.onSurfaceVariant;
    final base = GoogleFonts.tajawalTextTheme(const TextTheme());

    return base.copyWith(
      // مشتقّان أكبر من المقياس — لشاشات البداية والعناوين الضخمة فقط.
      displayLarge: _tajawal(
        size: 28,
        weight: FontWeight.w700,
        lineHeight: 38,
        color: primary,
      ),
      displayMedium: _tajawal(
        size: 24,
        weight: FontWeight.w700,
        lineHeight: 34,
        color: primary,
      ),
      headlineSmall: _tajawal(
        size: 22,
        weight: FontWeight.w700,
        lineHeight: 30,
        color: primary,
      ),
      titleLarge: _tajawal(
        size: 20,
        weight: FontWeight.w700,
        lineHeight: 28,
        color: primary,
      ),
      titleMedium: _tajawal(
        size: 19,
        weight: FontWeight.w700,
        lineHeight: 27,
        color: primary,
      ),
      titleSmall: _tajawal(
        size: 16,
        weight: FontWeight.w500,
        lineHeight: 22,
        color: primary,
      ),
      bodyLarge: _tajawal(
        size: 17,
        weight: FontWeight.w400,
        lineHeight: 26,
        color: primary,
      ),
      bodyMedium: _tajawal(
        size: 16,
        weight: FontWeight.w400,
        lineHeight: 24,
        color: primary,
      ),
      bodySmall: _tajawal(
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 20,
        color: secondary,
      ),
      labelLarge: _tajawal(
        size: 17,
        weight: FontWeight.w500,
        lineHeight: 22,
        color: primary,
      ),
      labelMedium: _tajawal(
        size: 14,
        weight: FontWeight.w500,
        lineHeight: 20,
        color: secondary,
      ),
      labelSmall: _tajawal(
        size: 13,
        weight: FontWeight.w500,
        lineHeight: 18,
        color: secondary,
      ),
    );
  }
}
