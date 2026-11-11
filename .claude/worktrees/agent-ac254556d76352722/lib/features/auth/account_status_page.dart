import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// شاشة حالة الحساب — تحجب التطبيق عندما يكون الحساب قيد المراجعة أو مرفوضاً
// (الراوتر يوجّه إليها تلقائياً). «تحديث الحالة» يسأل /auth/me ويحدّث الجلسة؛
// عند القبول يعيد الراوتر المستخدم إلى الرئيسية مباشرة.
class AccountStatusPage extends ConsumerStatefulWidget {
  const AccountStatusPage({super.key});

  @override
  ConsumerState<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends ConsumerState<AccountStatusPage> {
  bool _refreshing = false;

  // الصيدلي أولاً — جلسة واحدة فقط تكون غير مقبولة في العادة.
  bool get _isPharmacy {
    final ph = ref.read(pharmacySessionProvider).value;
    return ph is SessionAuthenticated &&
        ph.accountStatus != AccountStatus.approved;
  }

  AccountStatus get _status {
    final ph = ref.watch(pharmacySessionProvider).value;
    if (ph is SessionAuthenticated &&
        ph.accountStatus != AccountStatus.approved) {
      return ph.accountStatus;
    }
    final wh = ref.watch(warehouseSessionProvider).value;
    if (wh is WarehouseSessionAuthenticated) return wh.accountStatus;
    return AccountStatus.approved;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final api = ref.read(apiClientProvider);
      final isPharmacy = _isPharmacy;
      final data = await api.get(
        isPharmacy ? ApiEndpoints.phMe : ApiEndpoints.whMe,
      ) as Map<String, dynamic>;
      final status = AccountStatus.fromApi(data['accountStatus']);
      if (isPharmacy) {
        await ref
            .read(pharmacySessionProvider.notifier)
            .setAccountStatus(status);
      } else {
        await ref
            .read(warehouseSessionProvider.notifier)
            .setAccountStatus(status);
      }
      if (mounted && status != AccountStatus.approved) {
        AppSnackbar.show(context, 'لا جديد — ما زال الحساب بنفس الحالة');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    if (_isPharmacy) {
      await ref.read(pharmacySessionProvider.notifier).clear();
    } else {
      await ref.read(warehouseSessionProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rejected = _status == AccountStatus.rejected;

    final iconColor = rejected ? t.danger : t.warning;
    final circleColor = rejected ? t.dangerSurface : t.warningSurface;

    return Scaffold(
      body: SafeArea(
        child: CenteredContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        rejected ? AppIcons.x : AppIcons.clock,
                        size: 32,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: StatusBadge(
                    label: rejected ? 'الحساب مرفوض' : 'قيد المراجعة',
                    tone: rejected ? StatusTone.danger : StatusTone.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  rejected ? 'نأسف، لم يُقبل حسابك' : 'حسابك قيد المراجعة',
                  textAlign: TextAlign.center,
                  style: context.text.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  rejected
                      ? 'لم تتم الموافقة على طلب التسجيل. تواصل مع فريق توريد لمعرفة السبب أو لإعادة التقديم.'
                      : 'يراجع فريق توريد بيانات حسابك الآن، وسيُفعَّل فور الموافقة. يمكنك تحديث الحالة في أي وقت.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!rejected) ...[
                  AppButton(
                    label: 'تحديث الحالة',
                    loading: _refreshing,
                    onPressed: _refreshing ? null : _refresh,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: 'تسجيل الخروج',
                  variant: AppButtonVariant.outline,
                  onPressed: _logout,
                ),
                const SizedBox(height: AppSpacing.x3l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
