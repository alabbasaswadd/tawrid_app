import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';

class WhOffersPage extends ConsumerWidget {
  const WhOffersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروضي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('عرض جديد'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_outlined, size: 64, color: TawridColors.hint),
              const SizedBox(height: AppSpacing.md),
              Text('لا توجد عروض',
                  style: GoogleFonts.cairo(
                      color: TawridColors.hint,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text('أنشئ عروض بيع لتعرضها على الصيدليات',
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
