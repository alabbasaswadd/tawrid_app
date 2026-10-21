import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/shared/widgets/gradient_card.dart';

class WhHomePage extends ConsumerWidget {
  const WhHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
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
              gradient: TawridColors.warehouseGradient,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً بك',
                            style: GoogleFonts.cairo(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13)),
                        Text('مستودعك',
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('إدارة متكاملة لعمليات التوريد',
                            style: GoogleFonts.cairo(
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
                    child: const Icon(Icons.warehouse_outlined,
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
                        label: 'الطلبيات الواردة',
                        value: '—',
                        icon: Icons.inbox_outlined,
                        color: TawridColors.primary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: StatCard(
                        label: 'المناقصات المفتوحة',
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
                        label: 'عروضي النشطة',
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
            Text('الطلبيات الأخيرة',
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
                      Text('لا توجد طلبيات حديثة',
                          style: GoogleFonts.cairo(
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
