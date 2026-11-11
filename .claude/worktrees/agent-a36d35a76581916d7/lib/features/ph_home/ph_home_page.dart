import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

class PhHomePage extends ConsumerWidget {
  const PhHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final heroGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة الترحيب
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً بك',
                            style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                        Text('صيدليتك',
                            style: context.text.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('إدارة متكاملة للتوريد الدوائي',
                            style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('بحث سريع', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SearchActionCard(
                    icon: Icons.sell_outlined,
                    title: 'ابحث عن عرض',
                    subtitle: 'عروض المستودعات في منطقتك',
                    onTap: () => context.push(TRoutes.phOffers),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SearchActionCard(
                    icon: Icons.medication_outlined,
                    title: 'ابحث عن دواء',
                    subtitle: 'تفاصيل وأسعار الأدوية',
                    onTap: () => context.push(TRoutes.phMedicineSearch),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('آخر النشاطات', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: context.tokens.hint),
                  const SizedBox(height: AppSpacing.sm),
                  Text('لا توجد نشاطات حديثة', style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchActionCard extends StatelessWidget {
  const _SearchActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: cs.outline),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
