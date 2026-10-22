import 'package:flutter/material.dart';

// القيم الخام للتصميم — لا تُستهلك مباشرة في الشاشات، بل عبر الثيم/TawridTokens.
// طيف هادئ منخفض التشبّع يليق بجمهور مثقّف: لون أساسي واحد + محايدات دافئة.
abstract final class AppPalette {
  // ── اللون الأساسي (تركواز-أخضر مغبّر) ──────────────────────────────
  static const brandLight = Color(0xFF2E8B73);
  static const brandDark = Color(0xFF4FB999);
  static const onBrandLight = Color(0xFFFFFFFF);
  static const onBrandDark = Color(0xFF0C1A15);

  // ── الأدوار ─────────────────────────────────────────────────────────
  // قرار الهوية: لون أساسي واحد هادئ للطرفين (ألغي تمييز البنفسجي/الأخضر).
  // التمييز بين المستودع والصيدلية يكون بلمسة خفيفة (أيقونة/تسمية) لا بلون ثانٍ.
  static const pharmacyLight = brandLight;
  static const pharmacyDark = brandDark;
  static const warehouseLight = brandLight;
  static const warehouseDark = brandDark;

  // ── دلالات ─────────────────────────────────────────────────────────
  static const successLight = Color(0xFF2E7D52);
  static const successDark = Color(0xFF4FBF84);
  static const warningLight = Color(0xFFB9770E);
  static const warningDark = Color(0xFFE0A33E);
  static const errorLight = Color(0xFFC53B3B);
  static const errorDark = Color(0xFFE57373);
  static const infoLight = Color(0xFF2D6CB5);
  static const infoDark = Color(0xFF5B9BE0);

  // ── محايدات (فاتح) ────────────────────────────────────────────────
  static const bgLight = Color(0xFFF7F8F9);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF1F3F5);
  static const outlineLight = Color(0xFFE3E7EA);
  static const outlineStrongLight = Color(0xFFCDD4DA);
  static const textPrimaryLight = Color(0xFF1A2230);
  static const textSecondaryLight = Color(0xFF596273);
  static const textHintLight = Color(0xFF8A94A3);

  // ── محايدات (داكن) ────────────────────────────────────────────────
  static const bgDark = Color(0xFF0F1419);
  static const surfaceDark = Color(0xFF161C24);
  static const surfaceAltDark = Color(0xFF1E2630);
  static const outlineDark = Color(0xFF2A333F);
  static const outlineStrongDark = Color(0xFF3A4551);
  static const textPrimaryDark = Color(0xFFE6E8EB);
  static const textSecondaryDark = Color(0xFFA6B0BD);
  static const textHintDark = Color(0xFF6B7684);
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
