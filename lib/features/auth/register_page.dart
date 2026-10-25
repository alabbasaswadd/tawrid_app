import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/governorate_city_selector.dart';

class PhRegisterPage extends ConsumerStatefulWidget {
  const PhRegisterPage({super.key});

  @override
  ConsumerState<PhRegisterPage> createState() => _PhRegisterPageState();
}

class _PhRegisterPageState extends ConsumerState<PhRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _governorateId;
  String? _cityId;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final governorates = ref.read(governoratesProvider).value ?? [];
      final governorate = governorates.firstWhere((g) => g.id == _governorateId);
      final cityId = _cityId;
      final city = cityId == null
          ? null
          : governorate.cities.firstWhere((c) => c.id == cityId);

      final api = ref.read(apiClientProvider);
      await api.post(ApiEndpoints.phRegister, data: {
        'pharmacyName': _name.text.trim(),
        'governorate': governorate.name,
        'city': city?.name ?? '',
        'address': _address.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
      if (mounted) {
        AppSnackbar.success(context, 'تم إنشاء الحساب بنجاح، يمكنك الدخول الآن');
        context.go(TRoutes.phLogin);
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final heroGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => context.go(TRoutes.phLogin),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('تسجيل صيدلية جديدة',
                        style: context.text.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.sm),
                          Text('معلومات الصيدلية',
                              style: context.text.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text('أدخل بيانات الصيدلية لإنشاء حساب',
                              style: context.text.bodySmall),
                          const SizedBox(height: AppSpacing.lg),

                          AppTextField(
                            controller: _name,
                            label: 'اسم الصيدلية',
                            prefixIcon: Icons.local_pharmacy_outlined,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          GovernorateCitySelector(
                            governorateId: _governorateId,
                            cityId: _cityId,
                            onGovernorateChanged: (v) => setState(() => _governorateId = v),
                            onCityChanged: (v) => setState(() => _cityId = v),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            controller: _address,
                            label: 'العنوان (اختياري)',
                            prefixIcon: Icons.home_outlined,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            controller: _email,
                            label: 'البريد الإلكتروني',
                            hint: 'example@domain.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'مطلوب';
                              if (!v.contains('@')) return 'بريد غير صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            controller: _phone,
                            label: 'رقم الهاتف',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            controller: _password,
                            label: 'كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            obscure: true,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              if (v.length < 6) return 'لا تقل عن 6 أحرف';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          AppTextField(
                            controller: _confirm,
                            label: 'تأكيد كلمة المرور',
                            prefixIcon: Icons.lock_outline,
                            obscure: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              if (v != _password.text) return 'كلمتا المرور غير متطابقتين';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          AppButton(
                            label: 'إنشاء الحساب',
                            icon: Icons.person_add_outlined,
                            loading: _loading,
                            onPressed: _loading ? null : _register,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('لديك حساب بالفعل؟',
                                  style: context.text.bodySmall),
                              TextButton(
                                onPressed: () => context.go(TRoutes.phLogin),
                                child: const Text('دخول'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
