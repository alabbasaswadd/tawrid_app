import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class PhLoginPage extends ConsumerStatefulWidget {
  const PhLoginPage({super.key});

  @override
  ConsumerState<PhLoginPage> createState() => _PhLoginPageState();
}

class _PhLoginPageState extends ConsumerState<PhLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
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
                      style: context.text.displayMedium?.copyWith(color: Colors.white)),
                  Text('منصة التوريد الدوائي',
                      style: context.text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),

              // Form card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: CenteredContent(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.sm),
                            Text('دخول الصيدلية',
                                style: context.text.titleLarge),
                            const SizedBox(height: AppSpacing.xs),
                            Text('أدخل بيانات حسابك للمتابعة',
                                style: context.text.bodySmall),
                            const SizedBox(height: AppSpacing.lg),

                            AppTextField(
                              controller: _email,
                              label: 'البريد الإلكتروني',
                              hint: 'example@domain.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'البريد مطلوب' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            AppTextField(
                              controller: _password,
                              label: 'كلمة المرور',
                              prefixIcon: Icons.lock_outline,
                              obscure: true,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            AppButton(
                              label: 'دخول',
                              icon: Icons.login,
                              loading: _loading,
                              onPressed: _loading ? null : _login,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('ليس لديك حساب؟',
                                    style: context.text.bodySmall),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
