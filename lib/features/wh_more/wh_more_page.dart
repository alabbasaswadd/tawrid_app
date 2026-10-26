import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/warehouse_auth_models.dart';
import 'package:tawrid_app/repositories/warehouse_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// حساب المستودع (Figma: المستودع / حسابي).
//
// بطاقة هوية، ثم مجموعتان مفصولتان: «بيانات الحساب» و«التفضيلات» —
// وتسجيل الخروج وحده في بطاقة مستقلة حمراء، بعيداً عن الضغط العرضي.
class WhMorePage extends ConsumerWidget {
  const WhMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final tk = context.tokens;
    final me = ref.watch(warehouseMeProvider).value;
    final isAdmin = me?.role == WarehouseUserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        children: [
          _IdentityCard(me: me),

          const SizedBox(height: AppSpacing.lg),
          _GroupLabel('بيانات الحساب'),
          _Group(children: [
            _Row(
              icon: Icons.warehouse_outlined,
              label: 'بيانات المستودع',
              onTap: () => context.push(TRoutes.whProfile),
            ),
            _Row(
              icon: Icons.person_outline,
              label: 'المسؤول وبيانات التواصل',
              onTap: () => context.push(TRoutes.whProfile),
            ),
            _Row(
              icon: Icons.description_outlined,
              label: 'مناطق التغطية',
              // الملف الشخصي هو محرّر المناطق نفسه — لا شاشة ثالثة.
              onTap: () => context.push(TRoutes.whProfile),
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),
          _GroupLabel('التفضيلات'),
          _Group(children: [
            _Row(
              icon: Icons.notifications_outlined,
              label: 'الإشعارات',
              onTap: () => context.push(TRoutes.whNotificationSettings),
            ),
            // إدارة الموظّفين للمدير وحده — الخادم يفرضها بسياسة
            // Warehouse.Admin، فإظهارها للموظّف إرسالٌ إلى 403.
            if (isAdmin)
              _Row(
                icon: Icons.group_outlined,
                label: 'موظفو المستودع',
                onTap: () => context.push(TRoutes.whUsers),
              ),
            _Row(
              icon: Icons.campaign_outlined,
              label: 'إعلاناتي وأخباري',
              onTap: () => context.push(TRoutes.whListings),
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: () => _confirmLogout(context, ref),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 18, color: cs.error),
                const SizedBox(width: AppSpacing.sm),
                Text('تسجيل الخروج',
                    style: context.text.titleSmall?.copyWith(color: cs.error)),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('توريد — منصة التوريد الدوائي',
                style: context.text.labelSmall?.copyWith(color: tk.hint)),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(warehouseSessionProvider.notifier).clear();
              if (context.mounted) {
                AppSnackbar.success(context, 'تم تسجيل الخروج');
              }
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}

// بطاقة الهوية: اسم المستودع، المدينة والهاتف، وشارة التوثيق.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.me});
  final WarehouseMe? me;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me?.warehouseName ?? 'مستودعي',
                    style: context.text.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  me == null
                      ? '—'
                      : [me!.city, me!.phone]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // «موثّق» صادقة بحكم الوصول: الحساب غير المقبول يُحجب خلف شاشة
          // حالة الحساب ولا يبلغ هذه الشاشة أصلاً.
          const StatusBadge(
              label: 'موثّق',
              tone: StatusTone.success,
              icon: Icons.verified_outlined),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(color: tk.brandSurface, shape: BoxShape.circle),
            child: Center(
              child: AppIcon(AppIcons.warehouse, size: 22, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs, right: 2),
        child: Text(text,
            style: context.text.labelMedium
                ?.copyWith(color: context.tokens.hint, letterSpacing: 0.5)),
      );
}

// مجموعة صفوف في بطاقة واحدة بفواصل بينها (Figma) — لا بطاقة لكل صفّ.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 52, color: cs.outline),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: context.text.bodyMedium)),
            AppIcon(AppIcons.chevronForwardRtl, size: 16, color: tk.hint),
          ],
        ),
      ),
    );
  }
}
