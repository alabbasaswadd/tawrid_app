import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/governorate_city_selector.dart';

// تسجيل مستودع جديد — مرحلتان بالحقول التي يطلبها الباك إند:
// ١) المستودع: الاسم، المحافظة/المدينة، العنوان، الهاتف، البريد.
// ٢) مدير المستودع: الاسم، اسم المستخدم، شام كاش (اختياري)، كلمة المرور.
class WhRegisterPage extends ConsumerStatefulWidget {
  const WhRegisterPage({super.key});

  @override
  ConsumerState<WhRegisterPage> createState() => _WhRegisterPageState();
}

class _WhRegisterPageState extends ConsumerState<WhRegisterPage> {
  int _step = 0;

  // الخطوة ١: معلومات المستودع
  final _warehouseFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _governorateId;
  String? _cityId;

  // الخطوة ٢: المعلومات الشخصية
  final _personalFormKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _userName = TextEditingController();
  final _shamCash = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _userName.dispose();
    _shamCash.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _goToPersonalStep() {
    if (!(_warehouseFormKey.currentState?.validate() ?? false)) return;
    if (_governorateId == null) {
      AppSnackbar.error(context, 'اختر المحافظة');
      return;
    }
    setState(() => _step = 1);
  }

  void _goBackToWarehouseStep() => setState(() => _step = 0);

  Future<void> _register() async {
    if (!(_personalFormKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final governorates = ref.read(governoratesProvider).value ?? [];
      final governorate = governorates.firstWhere(
        (g) => g.id == _governorateId,
      );
      final cityId = _cityId;
      final city = cityId == null
          ? null
          : governorate.cities.firstWhere((c) => c.id == cityId);

      final api = ref.read(apiClientProvider);
      final data = await api.post(
        ApiEndpoints.whRegister,
        data: {
          'warehouseName': _name.text.trim(),
          'governorate': governorate.name,
          'city': city?.name ?? '',
          'address': _address.text.trim(),
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'userName': _userName.text.trim(),
          'shamCashAccount': _shamCash.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
        },
      ) as Map<String, dynamic>;

      // تأسيس الجلسة فوراً (كما يُعيدها التسجيل) للانتقال مباشرة إلى شاشة
      // مناطق التخديم دون طلب دخول إضافي.
      await ref
          .read(warehouseSessionProvider.notifier)
          .establish(
            token: data['token'] as String,
            warehouseUserId: data['warehouseUserId'] as String?,
            warehouseId: data['warehouseId'] as String?,
            accountStatus: AccountStatus.fromApi(data['accountStatus']),
          );

      if (mounted) {
        AppSnackbar.success(context, 'تم تسجيل المستودع بنجاح');
        context.go(TRoutes.whServiceAreas);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'تسجيل مستودع جديد',
        onBack: _step == 0
            ? () => context.go(TRoutes.whLogin)
            : _goBackToWarehouseStep,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.md,
            ),
            child: _StepIndicator(currentStep: _step),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _step == 0 ? _buildWarehouseStep() : _buildPersonalStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseStep() {
    return SingleChildScrollView(
      key: const ValueKey('warehouse-step'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      child: CenteredContent(
        child: Form(
          key: _warehouseFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('معلومات المستودع', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'أدخل بيانات المستودع للمتابعة',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _name,
                label: 'اسم المستودع',
                hint: 'مثال: مستودع الشفاء',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              GovernorateCitySelector(
                governorateId: _governorateId,
                cityId: _cityId,
                onGovernorateChanged: (v) => setState(() => _governorateId = v),
                onCityChanged: (v) => setState(() => _cityId = v),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _address,
                label: 'العنوان (اختياري)',
                hint: 'الشارع، أقرب معلم…',
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _phone,
                label: 'رقم الهاتف',
                hint: '09xxxxxxxx',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _email,
                label: 'البريد الإلكتروني',
                hint: 'example@domain.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  if (!v.contains('@')) return 'بريد غير صحيح';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppButton(label: 'التالي', onPressed: _goToPersonalStep),
              const SizedBox(height: AppSpacing.md),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('لديك حساب بالفعل؟', style: context.text.bodySmall),
                  AppButton(
                    label: 'دخول',
                    variant: AppButtonVariant.text,
                    fullWidth: false,
                    onPressed: () => context.go(TRoutes.whLogin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return SingleChildScrollView(
      key: const ValueKey('personal-step'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      child: CenteredContent(
        child: Form(
          key: _personalFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المعلومات الشخصية', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'بيانات مدير المستودع (حساب Admin)',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _firstName,
                      label: 'الاسم الأول',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _lastName,
                      label: 'اسم العائلة',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _userName,
                label: 'اسم المستخدم',
                hint: 'للدخول إلى الحساب لاحقاً',
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'لا يقل عن ٣ أحرف'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _shamCash,
                label: 'حساب شام كاش (اختياري)',
                hint: 'رقم الحساب لاستقبال الدفعات',
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _password,
                label: 'كلمة المرور',
                hint: 'لا تقل عن ٦ أحرف',
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  if (v.length < 6) return 'لا تقل عن 6 أحرف';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _confirm,
                label: 'تأكيد كلمة المرور',
                hint: 'أعد إدخال كلمة المرور',
                obscure: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'مطلوب';
                  if (v != _password.text) return 'كلمتا المرور غير متطابقتين';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppButton(
                label: 'تسجيل المستودع',
                loading: _loading,
                onPressed: _loading ? null : _register,
              ),
              const SizedBox(height: AppSpacing.sm),

              AppButton(
                label: 'رجوع لمعلومات المستودع',
                variant: AppButtonVariant.text,
                onPressed: _goBackToWarehouseStep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// مؤشّر مرحلتَي التسجيل — دائرتان متصلتان بخط يتلوّن حسب التقدّم،
// بألوان الثيم على خلفية الصفحة الفاتحة.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  static const _labels = ['معلومات المستودع', 'المعلومات الشخصية'];

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStepDone = (i - 1) ~/ 2 < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              color: leftStepDone ? cs.primary : cs.outline,
            ),
          );
        }
        final step = i ~/ 2;
        final isActive = step == currentStep;
        final isDone = step < currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isActive || isDone)
                    ? cs.primary
                    : context.tokens.brandSurface,
                border: Border.all(
                  color: (isActive || isDone) ? cs.primary : cs.outline,
                ),
              ),
              child: isDone
                  ? AppIcon(AppIcons.check, size: 14, color: cs.onPrimary)
                  : Text(
                      '${step + 1}',
                      style: context.text.labelSmall?.copyWith(
                        color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: 90,
              child: Text(
                _labels[step],
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
