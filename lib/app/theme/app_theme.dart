import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_spacing.dart';
import 'app_tokens_ext.dart';
import 'app_typography.dart';
import 'tokens.dart';

// الثيم المركزي — يُبنى الوضعان (فاتح/داكن) من نفس الدلالات، مطابقاً
// لنظام تصميم Figma «توريد»: زر ٤٨/زاوية ١٢، حقل بحد ٢px عند التركيز،
// بطاقة بزاوية ١٦ وحد #E3EAE6. الشاشات تستهلك عبر Theme.of / context.tokens.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final brand = isDark ? AppPalette.brandDark : AppPalette.brandLight;
    final onBrand = isDark ? AppPalette.onBrandDark : AppPalette.onBrandLight;
    final gold = isDark ? AppPalette.goldDark : AppPalette.goldLight;
    final onGold = isDark ? AppPalette.onGoldDark : AppPalette.onGoldLight;
    final bg = isDark ? AppPalette.bgDark : AppPalette.bgLight;
    final surface = isDark ? AppPalette.surfaceDark : AppPalette.surfaceLight;
    final surfaceAlt = isDark
        ? AppPalette.surfaceAltDark
        : AppPalette.surfaceAltLight;
    final outline = isDark ? AppPalette.outlineDark : AppPalette.outlineLight;
    final textPrimary = isDark
        ? AppPalette.textPrimaryDark
        : AppPalette.textPrimaryLight;
    final textSecondary = isDark
        ? AppPalette.textSecondaryDark
        : AppPalette.textSecondaryLight;
    final error = isDark ? AppPalette.errorDark : AppPalette.errorLight;
    final tokens = isDark ? TawridTokens.dark : TawridTokens.light;

    final scheme =
        ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
          primary: brand,
          onPrimary: onBrand,
          secondary: brand,
          onSecondary: onBrand,
          tertiary: gold,
          onTertiary: onGold,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          surfaceContainerHighest: surfaceAlt,
          outline: outline,
          outlineVariant: outline,
          error: error,
          onError: Colors.white,
        );

    final textTheme = AppTypography.textTheme(scheme);
    final overlay = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [tokens],

      // الأشرطة العلوية تجلس على خلفية الصفحة نفسها (بلا سطح مرتفع).
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: outline),
        ),
        margin: EdgeInsets.zero,
      ),

      // حقل الإدخال: سطح أبيض + حد ١px، تركيز بحد أخضر ٢px، خطأ بحد ١٫٥px.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
        helperStyle: textTheme.labelSmall?.copyWith(color: textSecondary),
        errorStyle: textTheme.labelSmall?.copyWith(color: error),
      ),

      // الزر الأساسي: ٤٨ ارتفاعاً، زاوية ١٢، نص زر ١٥ Medium، معطل بشفافية ٤٥٪.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: onBrand,
          disabledBackgroundColor: brand.withValues(alpha: 0.45),
          disabledForegroundColor: onBrand.withValues(alpha: 0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 48),
        ),
      ),

      // الزر الثانوي: سطح أبيض + حد أخضر ١٫٥px.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          backgroundColor: surface,
          side: BorderSide(color: brand, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 48),
        ),
      ),

      // الزر النصي: للإجراءات الخفيفة.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 48),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        shape: StadiumBorder(side: BorderSide(color: outline)),
        labelStyle: textTheme.bodySmall,
        side: BorderSide(color: outline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),

      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        labelColor: brand,
        unselectedLabelColor: textSecondary,
        indicatorColor: brand,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: onBrand,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? brand
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? brand
                : textSecondary,
          ),
        ),
      ),
    );
  }
}
