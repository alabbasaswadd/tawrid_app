import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';

class WhTendersPage extends ConsumerWidget {
  const WhTendersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('المناقصات')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gavel_outlined, size: 64, color: TawridColors.hint),
              const SizedBox(height: AppSpacing.md),
              Text('لا توجد مناقصات مفتوحة',
                  style: GoogleFonts.cairo(
                      color: TawridColors.hint,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text('ستظهر هنا مناقصات الصيدليات المفتوحة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      color: TawridColors.hint, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
