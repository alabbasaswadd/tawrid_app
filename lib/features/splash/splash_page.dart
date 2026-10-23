import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: TawridColors.brandGradient),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 56),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('توريد',
                    style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('منصة التوريد الدوائي',
                    style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16)),
                const SizedBox(height: AppSpacing.xxl),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      );
}
