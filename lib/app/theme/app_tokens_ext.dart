import 'package:flutter/material.dart';
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
    required this.warning,
    required this.info,
    required this.pharmacy,
    required this.warehouse,
    required this.gold,
  });

  final Color surfaceAlt;
  final Color outlineStrong;
  final Color hint;
  final Color success;
  final Color warning;
  final Color info;
  final Color pharmacy;
  final Color warehouse;
  final Color gold;

  static const light = TawridTokens(
    surfaceAlt: AppPalette.surfaceAltLight,
    outlineStrong: AppPalette.outlineStrongLight,
    hint: AppPalette.textHintLight,
    success: AppPalette.successLight,
    warning: AppPalette.warningLight,
    info: AppPalette.infoLight,
    pharmacy: AppPalette.pharmacyLight,
    warehouse: AppPalette.warehouseLight,
    gold: AppPalette.goldLight,
  );

  static const dark = TawridTokens(
    surfaceAlt: AppPalette.surfaceAltDark,
    outlineStrong: AppPalette.outlineStrongDark,
    hint: AppPalette.textHintDark,
    success: AppPalette.successDark,
    warning: AppPalette.warningDark,
    info: AppPalette.infoDark,
    pharmacy: AppPalette.pharmacyDark,
    warehouse: AppPalette.warehouseDark,
    gold: AppPalette.goldDark,
  );

  @override
  TawridTokens copyWith({
    Color? surfaceAlt,
    Color? outlineStrong,
    Color? hint,
    Color? success,
    Color? warning,
    Color? info,
    Color? pharmacy,
    Color? warehouse,
    Color? gold,
  }) {
    return TawridTokens(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      hint: hint ?? this.hint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      pharmacy: pharmacy ?? this.pharmacy,
      warehouse: warehouse ?? this.warehouse,
      gold: gold ?? this.gold,
    );
  }

  @override
  TawridTokens lerp(ThemeExtension<TawridTokens>? other, double t) {
    if (other is! TawridTokens) return this;
    return TawridTokens(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      pharmacy: Color.lerp(pharmacy, other.pharmacy, t)!,
      warehouse: Color.lerp(warehouse, other.warehouse, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
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
}
