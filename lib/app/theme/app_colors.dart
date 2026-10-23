import 'package:flutter/material.dart';
import 'tokens.dart';

// LEGACY — تُهجَر تدريجياً إلى ColorScheme / context.tokens. أُعيد توجيه قيمها
// إلى اللوحة الهادئة الموحّدة (AppPalette) حتى تتوحّد الشاشات غير المهاجَرة بعد
// فوراً على نفس الهوية (لون أساسي واحد هادئ، بلا بنفسجي).
abstract final class TawridColors {
  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary = AppPalette.brandLight;
  static const Color primaryLight = Color(0xFF4FB999);
  static const Color primaryDark = Color(0xFF246E5B);
  static const Color accent = AppPalette.brandLight;

  // ── Gradients (موحّدة على اللون الأساسي) ──────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E8B73), Color(0xFF246E5B)],
  );
  static const LinearGradient warehouseGradient = brandGradient;
  static const LinearGradient pharmacyGradient = brandGradient;

  // ── Role colors (موحّدة) ───────────────────────────────────────────
  static const Color pharmacy = AppPalette.brandLight;
  static const Color warehouse = AppPalette.brandLight;

  // ── Semantic (هادئة) ───────────────────────────────────────────────
  static const Color success = AppPalette.successLight;
  static const Color warning = AppPalette.warningLight;
  static const Color error = AppPalette.errorLight;
  static const Color info = AppPalette.infoLight;

  // ── Neutrals ───────────────────────────────────────────────────────
  static const Color background = AppPalette.bgLight;
  static const Color surface = AppPalette.surfaceLight;
  static const Color surfaceVariant = AppPalette.surfaceAltLight;
  static const Color border = AppPalette.outlineLight;
  static const Color hint = AppPalette.textHintLight;
  static const Color textPrimary = AppPalette.textPrimaryLight;
  static const Color textSecondary = AppPalette.textSecondaryLight;

  // ── Status (هادئة) ─────────────────────────────────────────────────
  static const Color statusPending = AppPalette.warningLight;
  static const Color statusAccepted = AppPalette.infoLight;
  static const Color statusProcessing = AppPalette.brandLight;
  static const Color statusReady = AppPalette.infoLight;
  static const Color statusDelivering = AppPalette.infoLight;
  static const Color statusCompleted = AppPalette.successLight;
  static const Color statusCancelled = AppPalette.errorLight;
}
