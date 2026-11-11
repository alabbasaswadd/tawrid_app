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
import 'package:tawrid_app/shared/widgets/location_field.dart';
import 'package:tawrid_app/shared/widgets/governorate_city_selector.dart';

// تسجيل صيدلية جديدة — بالحقول التي يطلبها الباك إند:
// الاسم، المحافظة، المدينة، العنوان (اختياري)، البريد، الهاتف، كلمة المرور.
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
  double? _latitude;
  double? _longitude;
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
    if (_governorateId == null) {
      AppSnackbar.error(context, 'اختر المحافظة');
      return;
    }
    // الموقع إجباري: المستودعات تُصفّى بمدينة الصيدلية، والإحداثيات هي ما
    // يسمح لاحقاً بحساب الأقرب فعلاً لا الأقرب بالاسم.
    if (_latitude == null || _longitude == null) {
      AppSnackbar.error(context, 'حدّد موقع الصيدلية قبل إنشاء الحساب');
      return;
    }
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
      await api.post(
        ApiEndpoints.phRegister,
        data: {
          'pharmacyName': _name.text.trim(),
          'governorate': governorate.name,
          'city': city?.name ?? '',
          'address': _address.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'latitude': _latitude,
          'longitude': _longitude,
        },
      );
      if (mounted) {
        AppSnackbar.success(
          context,
          'تم إنشاء الحساب بنجاح، يمكنك الدخول الآن',
        );
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
    return Scaffold(
      appBar: InnerTopBar(
        title: 'تسجيل صيدلية جديدة',
        onBack: () => context.go(TRoutes.phLogin),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.x3l,
        ),
        child: CenteredContent(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('معلومات الصيدلية', style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'أدخل بيانات الصيدلية لإنشاء حساب',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),

                AppTextField(
                  controller: _name,
                  label: 'اسم الصيدلية',
                  hint: 'مثال: صيدلية النور',
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.lg),

                GovernorateCitySelector(
                  governorateId: _governorateId,
                  cityId: _cityId,
                  onGovernorateChanged: (v) =>
                      setState(() => _governorateId = v),
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
                  controller: _email,
                  label: 'البريد الإلكتروني',
                  hint: 'example@domain.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    if (!v.contains('@')) return 'بريد غير صحيح';
                    return null;
                  },
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
                    if (v != _password.text) {
                      return 'كلمتا المرور غير متطابقتين';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                LocationField(
                  latitude: _latitude,
                  longitude: _longitude,
                  onCaptured: (lat, lng) => setState(() {
                    _latitude = lat;
                    _longitude = lng;
                  }),
                ),
                const SizedBox(height: AppSpacing.x2l),

                AppButton(
                  label: 'إنشاء الحساب',
                  loading: _loading,
                  onPressed: _loading ? null : _register,
                ),
                const SizedBox(height: AppSpacing.md),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('لديك حساب بالفعل؟', style: context.text.bodySmall),
                    AppButton(
                      label: 'دخول',
                      variant: AppButtonVariant.text,
                      fullWidth: false,
                      onPressed: () => context.go(TRoutes.phLogin),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
