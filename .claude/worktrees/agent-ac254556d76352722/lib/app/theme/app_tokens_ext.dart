import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'tokens.dart';

// ألوان دلالية إضافية لا يوفّرها ColorScheme — متكيّفة مع الوضعين.
// تُقرأ في الشاشات عبر context.tokens.
@immutable
class TawridTokens extends ThemeExtension<TawridTokens> {
  const TawridTokens({
    required this.surfaceAlt,
    required this.outlineStrong,
    required this.hint,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.info,
    required this.pharmacy,
    required this.warehouse,
    required this.gold,
    required this.goldStrong,
    required this.goldSurface,
    required this.brandDeep,
    required this.brandSurface,
    required this.brandSurfaceSubtle,
  });

  final Color surfaceAlt;
  final Color outlineStrong;
  final Color hint;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color danger;
  final Color dangerSurface;
  final Color info;
  final Color pharmacy;
  final Color warehouse;

  // الذهبي — شارة البونص والعروض المميزة فقط.
  final Color gold;
  final Color goldStrong;
  final Color goldSurface;

  // الأخضر الداكن (#064A3F) — الظلال والتدرّجات وحالات الضغط.
  final Color brandDeep;

  // أسطح العلامة — خلفية خضراء فاتحة للشارات والأيقونات الدائرية.
  final Color brandSurface;
  final Color brandSurfaceSubtle;

  // ظل البطاقة الموحّد (Figma: 0 2 8 — الأخضر الداكن بشفافية ٦٪).
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: brandDeep.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ظل شريط التنقل السفلي (Figma: 0 -2 12 — بشفافية ٨٪).
  List<BoxShadow> get navShadow => [
    BoxShadow(
      color: brandDeep.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, -2),
    ),
  ];

  static const light = TawridTokens(
    surfaceAlt: AppPalette.surfaceAltLight,
    outlineStrong: AppPalette.outlineStrongLight,
    hint: AppPalette.textHintLight,
    success: AppPalette.successLight,
    successSurface: AppPalette.successSurfaceLight,
    warning: AppPalette.warningLight,
    warningSurface: AppPalette.warningSurfaceLight,
    danger: AppPalette.errorLight,
    dangerSurface: AppPalette.errorSurfaceLight,
    info: AppPalette.infoLight,
    pharmacy: AppPalette.pharmacyLight,
    warehouse: AppPalette.warehouseLight,
    gold: AppPalette.goldLight,
    goldStrong: AppPalette.goldStrongLight,
    goldSurface: AppPalette.goldSurfaceLight,
    brandDeep: AppPalette.brandDeepLight,
    brandSurface: AppPalette.brandSurfaceLight,
    brandSurfaceSubtle: AppPalette.brandSurfaceSubtleLight,
  );

  static const dark = TawridTokens(
    surfaceAlt: AppPalette.surfaceAltDark,
    outlineStrong: AppPalette.outlineStrongDark,
    hint: AppPalette.textHintDark,
    success: AppPalette.successDark,
    successSurface: AppPalette.successSurfaceDark,
    warning: AppPalette.warningDark,
    warningSurface: AppPalette.warningSurfaceDark,
    danger: AppPalette.errorDark,
    dangerSurface: AppPalette.errorSurfaceDark,
    info: AppPalette.infoDark,
    pharmacy: AppPalette.pharmacyDark,
    warehouse: AppPalette.warehouseDark,
    gold: AppPalette.goldDark,
    goldStrong: AppPalette.goldStrongDark,
    goldSurface: AppPalette.goldSurfaceDark,
    brandDeep: AppPalette.brandDeepDark,
    brandSurface: AppPalette.brandSurfaceDark,
    brandSurfaceSubtle: AppPalette.brandSurfaceSubtleDark,
  );

  @override
  TawridTokens copyWith({
    Color? surfaceAlt,
    Color? outlineStrong,
    Color? hint,
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? info,
    Color? pharmacy,
    Color? warehouse,
    Color? gold,
    Color? goldStrong,
    Color? goldSurface,
    Color? brandDeep,
    Color? brandSurface,
    Color? brandSurfaceSubtle,
  }) {
    return TawridTokens(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      hint: hint ?? this.hint,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      info: info ?? this.info,
      pharmacy: pharmacy ?? this.pharmacy,
      warehouse: warehouse ?? this.warehouse,
      gold: gold ?? this.gold,
      goldStrong: goldStrong ?? this.goldStrong,
      goldSurface: goldSurface ?? this.goldSurface,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSurface: brandSurface ?? this.brandSurface,
      brandSurfaceSubtle: brandSurfaceSubtle ?? this.brandSurfaceSubtle,
    );
  }

  @override
  TawridTokens lerp(ThemeExtension<TawridTokens>? other, double t) {
    if (other is! TawridTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return TawridTokens(
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      outlineStrong: l(outlineStrong, other.outlineStrong),
      hint: l(hint, other.hint),
      success: l(success, other.success),
      successSurface: l(successSurface, other.successSurface),
      warning: l(warning, other.warning),
      warningSurface: l(warningSurface, other.warningSurface),
      danger: l(danger, other.danger),
      dangerSurface: l(dangerSurface, other.dangerSurface),
      info: l(info, other.info),
      pharmacy: l(pharmacy, other.pharmacy),
      warehouse: l(warehouse, other.warehouse),
      gold: l(gold, other.gold),
      goldStrong: l(goldStrong, other.goldStrong),
      goldSurface: l(goldSurface, other.goldSurface),
      brandDeep: l(brandDeep, other.brandDeep),
      brandSurface: l(brandSurface, other.brandSurface),
      brandSurfaceSubtle: l(brandSurfaceSubtle, other.brandSurfaceSubtle),
    );
  }
}

extension TawridTokensX on BuildContext {
  // الدلالات الإضافية.
  TawridTokens get tokens =>
      Theme.of(this).extension<TawridTokens>() ?? TawridTokens.light;

  // اختصارات شائعة.
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  // «سعر وأرقام» — Tajawal Bold 16/22 بلون النص الرئيسي.
  TextStyle get priceStyle => AppTypography.price(colors.onSurface);

  // نفس الطراز بلون العلامة — لإجمالي العرض في البطاقات.
  TextStyle get priceBrandStyle => AppTypography.price(colors.primary);
}
