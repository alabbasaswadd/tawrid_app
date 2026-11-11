import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_spacing.dart';
import 'app_tokens_ext.dart';
import 'app_typography.dart';
import 'tokens.dart';

// الثيم المركزي — يُبنى الوضعان (فاتح/داكن) من نفس الدلالات.
// الشاشات تستهلك عبر Theme.of(context) / context.tokens — لا ثوابت لونية فيها.
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
    final surfaceAlt = isDark ? AppPalette.surfaceAltDark : AppPalette.surfaceAltLight;
    final outline = isDark ? AppPalette.outlineDark : AppPalette.outlineLight;
    final textPrimary = isDark ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight;
    final textSecondary = isDark ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight;
    final hint = isDark ? AppPalette.textHintDark : AppPalette.textHintLight;
    final error = isDark ? AppPalette.errorDark : AppPalette.errorLight;
    final tokens = isDark ? TawridTokens.dark : TawridTokens.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(
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
    final overlay = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [tokens],

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: textPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: outline),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: error),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: hint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: onBrand,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          minimumSize: const Size(0, 50),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: textTheme.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        shape: StadiumBorder(side: BorderSide(color: outline)),
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: outline),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        labelColor: brand,
        unselectedLabelColor: hint,
        indicatorColor: brand,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: onBrand,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? brand : hint,
            )),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
    );
  }
}
