import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/repositories/auth_password_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// إعادة تعيين إجبارية لكلمة المرور.
///
/// تظهر للحسابات التي ما زالت بكلمة المرور التي أُنشئت بها — وهي حسابات
/// مبذورة من سجلّ النقابة، كلماتُها مشتقّة جزئياً من أرقام سجلّ علنية.
///
/// الحجب ليس هنا: الخادم يرفض كل مسار عدا هذا ما دام العلَم مرفوعاً
/// (<c>PasswordChangedRequirement</c>). هذه الشاشة تُظهر السبب وتفتح
/// المخرج، ولا تُؤتمَن وحدها على المنع.
class ForcePasswordChangePage extends ConsumerStatefulWidget {
  const ForcePasswordChangePage({super.key});

  @override
  ConsumerState<ForcePasswordChangePage> createState() =>
      _ForcePasswordChangePageState();
}

class _ForcePasswordChangePageState
    extends ConsumerState<ForcePasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// أي جهة تحمل الجلسة الآن — الشاشة واحدة لكليهما، والمسار يختلف.
  bool get _isWarehouse =>
      ref.read(warehouseSessionProvider).value is WarehouseSessionAuthenticated;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(authPasswordRepositoryProvider);
      final warehouse = _isWarehouse;

      // بلا كلمة المرور الحالية: التوكن الذي وصل به إلى هنا صدر عن دخولٍ
      // بها قبل لحظات، فإعادةُ سؤاله عنها تَطلُب ما أثبته للتوّ. والخادم
      // يسمح بإغفالها في هذه الحالة وحدها (MustChangePassword).
      await repo.changePassword(
        isWarehouse: warehouse,
        newPassword: _next.text,
      );

      // رفع العلَم محلياً بعد نجاح الخادم — الموجِّه يستمع للجلسة فينتقل
      // تلقائياً إلى الرئيسية.
      if (warehouse) {
        await ref.read(warehouseSessionProvider.notifier)
            .clearMustChangePassword();
      } else {
        await ref.read(pharmacySessionProvider.notifier)
            .clearMustChangePassword();
      }

      if (!mounted) return;
      AppSnackbar.success(context, 'تم تغيير كلمة المرور — أهلاً بك');
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return Scaffold(
      // بلا زرّ رجوع ولا خروج: الحساب محجوب على الخادم أصلاً، فزرٌّ يوهم
      // بمخرجٍ آخر يُفضي إلى شاشة فارغة لا إلى تطبيق.
      appBar: const InnerTopBar(
        title: 'تعيين كلمة مرور جديدة',
        // بلا زرّ رجوع: الحساب محجوب على الخادم، فزرٌّ معطَّل يبقى دائرةً
        // فارغة تُقرأ عطلاً — وإخفاؤه أصدق من تعطيله.
        showBack: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.x3l,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: tk.warningSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 20, color: tk.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'حسابك ما زال بكلمة المرور التي أُنشئ بها. لحمايته، '
                      'غيّرها الآن — لن تتمكّن من استعمال التطبيق قبل ذلك.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.x2l),
            AppTextField(
              controller: _next,
              label: 'كلمة المرور الجديدة',
              obscure: true,
              validator: (v) => (v == null || v.length < 8)
                  ? 'ثمانية أحرف على الأقل'
                  : null,
            ),

            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _confirm,
              label: 'تأكيد كلمة المرور الجديدة',
              obscure: true,
              validator: (v) =>
                  v != _next.text ? 'الكلمتان غير متطابقتين' : null,
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: context.text.bodySmall?.copyWith(color: tk.danger),
              ),
            ],

            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: _saving ? 'جارٍ الحفظ…' : 'حفظ ومتابعة',
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
