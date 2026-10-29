import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/models/pharmacy_auth_models.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// حساب الصيدلية (Figma: الصيدلي / حسابي).
//
// بطاقة هوية، ثم مجموعتان مفصولتان: «بيانات الحساب» و«التفضيلات» —
// وتسجيل الخروج في بطاقة مستقلة حمراء بعيداً عن الضغط العرضي.
class PhMorePage extends ConsumerWidget {
  const PhMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final tk = context.tokens;
    final me = ref.watch(pharmacyMeProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        children: [
          _IdentityCard(me: me),

          const SizedBox(height: AppSpacing.lg),
          const _GroupLabel('بيانات الحساب'),
          _Group(children: [
            _Row(
              icon: Icons.local_pharmacy_outlined,
              label: 'بيانات الصيدلية',
              trailingText: me?.pharmacyName,
              onTap: () => context.push(TRoutes.phProfile),
            ),
            _Row(
              icon: Icons.person_outline,
              label: 'الصيدلي المسؤول',
              trailingText: me?.email,
              onTap: () => context.push(TRoutes.phProfile),
            ),
            _Row(
              icon: Icons.place_outlined,
              label: 'العنوان',
              trailingText: me?.areaLabel,
              onTap: () => context.push(TRoutes.phProfile),
            ),
          ]),

          const SizedBox(height: AppSpacing.lg),
          const _GroupLabel('التفضيلات'),
          _Group(children: [
            _Row(
              icon: Icons.notifications_outlined,
              label: 'الإشعارات',
              onTap: () => context.push(TRoutes.phNotificationSettings),
            ),
            _Row(
              icon: Icons.shopping_cart_outlined,
              label: 'السلة',
              onTap: () => context.push(TRoutes.phCart),
            ),
            _Row(
              icon: Icons.price_change_outlined,
              label: 'بحث الأسعار',
              onTap: () => context.push(TRoutes.phPriceSearch),
            ),
            _Row(
              icon: Icons.storefront_outlined,
              label: 'المستودعات المتاحة',
              onTap: () => context.push(TRoutes.phWarehouses),
            ),
            _Row(
              icon: Icons.campaign_outlined,
              label: 'إعلاناتي',
              onTap: () => context.push(TRoutes.phListings),
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
        content: const Text('هل تريد تسجيل الخروج من حساب الصيدلية؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(pharmacySessionProvider.notifier).clear();
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.me});
  final PharmacyMe? me;

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
                Text(me?.pharmacyName ?? 'صيدليتي',
                    style: context.text.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  me == null
                      ? '—'
                      : [me!.areaLabel, me!.phone]
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
              child: AppIcon(AppIcons.pill, size: 22, color: cs.primary),
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
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// قيمة مختصرة تظهر قبل السهم — «دمشق — المزة»، «موثّق».
  final String? trailingText;

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
            if (trailingText != null && trailingText!.isNotEmpty) ...[
              Flexible(
                child: Text(trailingText!,
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            AppIcon(AppIcons.chevronForwardRtl, size: 16, color: tk.hint),
          ],
        ),
      ),
    );
  }
}
