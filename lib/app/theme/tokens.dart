import 'package:flutter/material.dart';

// القيم الخام للتصميم — مصدرها ملف Figma «توريد | TAWREED» (صفحة الهوية ونظام
// التصميم). لا تُستهلك مباشرة في الشاشات، بل عبر الثيم / TawridTokens.
// الوضع الداكن مشتقّ من نفس الهوية (Figma يعرّف الوضع الفاتح فقط).
abstract final class AppPalette {
  // ── الأخضر الأساسي (#086653) والداكن (#064A3F) من اللوحة ────────────
  static const brandLight = Color(0xFF086653);
  static const brandDark = Color(0xFF3FA98D);
  static const onBrandLight = Color(0xFFFFFFFF);
  static const onBrandDark = Color(0xFF04291F);

  // الأخضر الداكن — للتدرّجات والظلال وحالات الضغط.
  static const brandDeepLight = Color(0xFF064A3F);
  static const brandDeepDark = Color(0xFF2E8A72);

  // أسطح العلامة — خلفية خضراء فاتحة (#E8F3EF) وأفتح منها (#F1F8F5).
  static const brandSurfaceLight = Color(0xFFE8F3EF);
  static const brandSurfaceDark = Color(0xFF143027);
  static const brandSurfaceSubtleLight = Color(0xFFF1F8F5);
  static const brandSurfaceSubtleDark = Color(0xFF102721);

  // ── الذهبي — الأساسي (#C6A45A)، الغامق للنص (#A9873F)، الفاتح (#F7F1E3) ──
  static const goldLight = Color(0xFFC6A45A);
  static const goldDark = Color(0xFFD4B878);
  static const goldStrongLight = Color(0xFFA9873F);
  static const goldStrongDark = Color(0xFFE0C98F);
  static const goldSurfaceLight = Color(0xFFF7F1E3);
  static const goldSurfaceDark = Color(0xFF2E2718);
  static const onGoldLight = Color(0xFF1A0D00);
  static const onGoldDark = Color(0xFF1A0D00);

  // ── الأدوار ─────────────────────────────────────────────────────────
  static const pharmacyLight = brandLight;
  static const pharmacyDark = brandDark;
  static const warehouseLight = brandLight;
  static const warehouseDark = brandDark;

  // ── دلالات: النجاح (#1F8A5B)، التحذير (#B45309)، الخطأ (#C03D33) ─────
  static const successLight = Color(0xFF1F8A5B);
  static const successDark = Color(0xFF4FBF8B);
  static const successSurfaceLight = Color(0xFFE6F4EC);
  static const successSurfaceDark = Color(0xFF11291D);
  static const warningLight = Color(0xFFB45309);
  static const warningDark = Color(0xFFE0A33E);
  static const warningSurfaceLight = Color(0xFFFCF3E3);
  static const warningSurfaceDark = Color(0xFF2E2412);
  static const errorLight = Color(0xFFC03D33);
  static const errorDark = Color(0xFFE57373);
  static const errorSurfaceLight = Color(0xFFFBEAE8);
  static const errorSurfaceDark = Color(0xFF331A18);
  static const infoLight = Color(0xFF2D6CB5);
  static const infoDark = Color(0xFF5B9BE0);

  // ── محايدات (فاتح): خلفية الصفحة (#F8FAF9)، الأسطح (#FFFFFF)،
  //    الحدود (#E3EAE6)، النص (#18332D / #71817B) ─────────────────────
  static const bgLight = Color(0xFFF8FAF9);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF1F5F3);
  static const outlineLight = Color(0xFFE3EAE6);
  static const outlineStrongLight = Color(0xFFC9D4CE);
  static const textPrimaryLight = Color(0xFF18332D);
  static const textSecondaryLight = Color(0xFF71817B);
  static const textHintLight = Color(0xFF93A29C);

  // ── محايدات (داكن) — مشتقّة بنفس الصبغة الخضراء ─────────────────────
  static const bgDark = Color(0xFF0D1613);
  static const surfaceDark = Color(0xFF131F1A);
  static const surfaceAltDark = Color(0xFF1A2A23);
  static const outlineDark = Color(0xFF2A3C33);
  static const outlineStrongDark = Color(0xFF3A5045);
  static const textPrimaryDark = Color(0xFFE4ECE8);
  static const textSecondaryDark = Color(0xFF9FB3AA);
  static const textHintDark = Color(0xFF6E8279);
}

// مدد الحركة الموحّدة.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

// عرض المحتوى الأقصى على الشاشات العريضة (توسيط بدل تمدّد قبيح).
abstract final class AppBreakpoints {
  static const double tablet = 720;
  static const double maxContentWidth = 640;
}
