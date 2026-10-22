import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class WhMorePage extends ConsumerWidget {
  const WhMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _SectionHeader(label: 'الخدمات'),
          _MoreTile(
            icon: Icons.campaign_outlined,
            label: 'إعلاناتي',
            color: t.warning,
            onTap: () => context.push(TRoutes.whListings),
          ),
          _MoreTile(
            icon: Icons.medication_outlined,
            label: 'أدويتي',
            color: cs.primary,
            onTap: () => context.push(TRoutes.whMedicines),
          ),
          _MoreTile(
            icon: Icons.bar_chart_outlined,
            label: 'التقارير',
            color: t.info,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          const _SectionHeader(label: 'الحساب'),
          _MoreTile(
            icon: Icons.business_outlined,
            label: 'ملف المستودع',
            color: cs.primary,
            onTap: () => context.push(TRoutes.whProfile),
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            label: 'الإعدادات',
            color: cs.onSurfaceVariant,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          _MoreTile(
            icon: Icons.logout,
            label: 'تسجيل الخروج',
            color: cs.error,
            onTap: () => _confirmLogout(context, ref),
            showArrow: false,
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text('توريد — منصة التوريد الدوائي',
                style: context.text.bodySmall?.copyWith(color: t.hint)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب المستودع؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(warehouseSessionProvider.notifier).clear();
              if (context.mounted) AppSnackbar.success(context, 'تم تسجيل الخروج');
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.sm),
        child: Text(label,
            style: context.text.labelMedium?.copyWith(color: context.tokens.hint, letterSpacing: 0.5)),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.showArrow = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(label, style: context.text.titleSmall),
          trailing: showArrow
              ? Icon(Icons.arrow_forward_ios, size: 14, color: context.tokens.hint)
              : null,
          onTap: onTap,
        ),
      );
}
