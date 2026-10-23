import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/shared/widgets/gradient_card.dart';

class PhHomePage extends ConsumerWidget {
  const PhHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientCard(
              gradient: TawridColors.pharmacyGradient,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً بك',
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13)),
                        Text('صيدليتك',
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('إدارة متكاملة للتوريد الدوائي',
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_pharmacy_outlined,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('نظرة عامة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                    child: StatCard(
                        label: 'الطلبيات',
                        value: '—',
                        icon: Icons.local_shipping_outlined,
                        color: TawridColors.primary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: StatCard(
                        label: 'المناقصات',
                        value: '—',
                        icon: Icons.gavel_outlined,
                        color: TawridColors.warehouse)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                    child: StatCard(
                        label: 'العروض المتاحة',
                        value: '—',
                        icon: Icons.sell_outlined,
                        color: TawridColors.success)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: StatCard(
                        label: 'إعلاناتي',
                        value: '—',
                        icon: Icons.campaign_outlined,
                        color: TawridColors.warning)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('آخر النشاطات',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48, color: TawridColors.hint),
                      const SizedBox(height: AppSpacing.sm),
                      Text('لا توجد نشاطات حديثة',
                          style: GoogleFonts.ibmPlexSansArabic(
                              color: TawridColors.hint, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
