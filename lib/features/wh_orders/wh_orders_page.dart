import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';

class WhOrdersPage extends ConsumerWidget {
  const WhOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبيات الواردة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: TawridColors.hint),
              const SizedBox(height: AppSpacing.md),
              Text('لا توجد طلبيات',
                  style: GoogleFonts.cairo(
                      color: TawridColors.hint,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text('ستظهر هنا طلبيات التوريد الواردة من الصيدليات',
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
