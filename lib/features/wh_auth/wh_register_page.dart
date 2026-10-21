import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/tawrid_button.dart';

class WhRegisterPage extends ConsumerStatefulWidget {
  const WhRegisterPage({super.key});

  @override
  ConsumerState<WhRegisterPage> createState() => _WhRegisterPageState();
}

class _WhRegisterPageState extends ConsumerState<WhRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
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
      final api = ref.read(apiClientProvider);
      await api.post(ApiEndpoints.whRegister, data: {
        'warehouseName': _name.text.trim(),
        'login': _login.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
      if (mounted) {
        AppSnackbar.success(context, 'تم تسجيل المستودع بنجاح، يمكنك الدخول الآن');
        context.go(TRoutes.whLogin);
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
      body: Container(
        decoration: const BoxDecoration(gradient: TawridColors.warehouseGradient),
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
                      onPressed: () => context.go(TRoutes.whLogin),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('تسجيل مستودع جديد',
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: TawridColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.sm),
                          Text('معلومات المستودع',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text('أدخل بيانات المستودع لإنشاء حساب',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.lg),

                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستودع',
                              prefixIcon: Icon(Icons.warehouse_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _login,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'مطلوب';
                              if (!v.contains('@')) return 'بريد غير صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              if (v.length < 6) return 'لا تقل عن 6 أحرف';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'مطلوب';
                              if (v != _password.text) return 'كلمتا المرور غير متطابقتين';
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          TawridButton(
                            label: 'تسجيل المستودع',
                            onPressed: _loading ? null : _register,
                            loading: _loading,
                            gradient: TawridColors.warehouseGradient,
                            icon: Icons.business_outlined,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('لديك حساب بالفعل؟',
                                  style: Theme.of(context).textTheme.bodySmall),
                              TextButton(
                                onPressed: () => context.go(TRoutes.whLogin),
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
