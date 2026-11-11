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
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/tawrid_button.dart';

class PhLoginPage extends ConsumerStatefulWidget {
  const PhLoginPage({super.key});

  @override
  ConsumerState<PhLoginPage> createState() => _PhLoginPageState();
}

class _PhLoginPageState extends ConsumerState<PhLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post(ApiEndpoints.phLogin, data: {
        'email': _email.text.trim(),
        'password': _password.text,
      }) as Map<String, dynamic>;
      await ref.read(pharmacySessionProvider.notifier).establish(
            token: data['token'] as String,
            userId: data['userId'] as String?,
            tenantId: data['tenantId'] as String?,
          );
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
        decoration: const BoxDecoration(gradient: TawridColors.pharmacyGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('توريد',
                      style: GoogleFonts.cairo(
                          color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('منصة التوريد الدوائي',
                      style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                ]),
              ),

              // Form card
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
                          Text('دخول الصيدلية',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text('أدخل بيانات حسابك للمتابعة',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                          const SizedBox(height: AppSpacing.lg),

                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'البريد مطلوب' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          TawridButton(
                            label: 'دخول',
                            onPressed: _loading ? null : _login,
                            loading: _loading,
                            gradient: TawridColors.pharmacyGradient,
                            icon: Icons.login,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('ليس لديك حساب؟',
                                  style: Theme.of(context).textTheme.bodySmall),
                              TextButton(
                                onPressed: () => context.go(TRoutes.phRegister),
                                child: const Text('إنشاء حساب'),
                              ),
                            ],
                          ),

                          const Divider(height: AppSpacing.xl),

                          OutlinedButton.icon(
                            onPressed: () => context.go(TRoutes.whLogin),
                            icon: const Icon(Icons.warehouse_outlined),
                            label: const Text('دخول كمستودع'),
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
