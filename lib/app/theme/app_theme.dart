import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TawridColors.primary,
        primary: TawridColors.primary,
        secondary: TawridColors.accent,
        surface: TawridColors.surface,
        error: TawridColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: TawridColors.background,
    );

    final cairoTextTheme = GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
      displayLarge:  GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.w800, color: TawridColors.textPrimary),
      displayMedium: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w700, color: TawridColors.textPrimary),
      titleLarge:    GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700, color: TawridColors.textPrimary),
      titleMedium:   GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600, color: TawridColors.textPrimary),
      titleSmall:    GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600, color: TawridColors.textPrimary),
      bodyLarge:     GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w400, color: TawridColors.textPrimary),
      bodyMedium:    GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w400, color: TawridColors.textPrimary),
      bodySmall:     GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w400, color: TawridColors.textSecondary),
      labelLarge:    GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: TawridColors.textPrimary),
      labelSmall:    GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: cairoTextTheme,
      primaryTextTheme: cairoTextTheme,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: TawridColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: TawridColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: TawridColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TawridColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: TawridColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: TawridColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: TawridColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: TawridColors.error),
        ),
        hintStyle: GoogleFonts.cairo(color: TawridColors.hint, fontSize: 14),
        labelStyle: GoogleFonts.cairo(color: TawridColors.textSecondary, fontSize: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TawridColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
          minimumSize: const Size(0, 50),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TawridColors.primary,
          side: const BorderSide(color: TawridColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TawridColors.primary,
          textStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: TawridColors.border)),
        labelStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      dividerTheme: DividerThemeData(
        color: TawridColors.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.cairo(fontSize: 14),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w500, fontSize: 13),
        labelColor: TawridColors.primary,
        unselectedLabelColor: TawridColors.hint,
        indicatorColor: TawridColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: TawridColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: TawridColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: TawridColors.primary.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? TawridColors.primary
              : TawridColors.hint,
        )),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
