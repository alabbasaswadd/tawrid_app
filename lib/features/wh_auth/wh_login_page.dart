import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class WhLoginPage extends ConsumerStatefulWidget {
  const WhLoginPage({super.key});

  @override
  ConsumerState<WhLoginPage> createState() => _WhLoginPageState();
}

class _WhLoginPageState extends ConsumerState<WhLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post(ApiEndpoints.whLogin, data: {
        'login': _username.text.trim(),
        'password': _password.text,
      }) as Map<String, dynamic>;
      await ref.read(warehouseSessionProvider.notifier).establish(
            token: data['token'] as String,
            warehouseUserId: data['warehouseUserId'] as String?,
            warehouseId: data['warehouseId'] as String?,
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
              // الترويسة
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.warehouse_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('توريد',
                      style: context.text.displayMedium?.copyWith(color: Colors.white)),
                  Text('بوابة المستودع',
                      style: context.text.bodyMedium
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),

              // بطاقة النموذج
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
                            Text('دخول المستودع', style: context.text.titleLarge),
                            const SizedBox(height: AppSpacing.xs),
                            Text('أدخل بيانات حساب المستودع', style: context.text.bodySmall),
                            const SizedBox(height: AppSpacing.lg),

                            AppTextField(
                              controller: _username,
                              label: 'اسم المستخدم أو البريد',
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            AppTextField(
                              controller: _password,
                              label: 'كلمة المرور',
                              prefixIcon: Icons.lock_outline,
                              obscure: true,
                              validator: (v) => (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            AppButton(
                              label: 'دخول',
                              icon: Icons.login,
                              loading: _loading,
                              onPressed: _login,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('مستودع جديد؟', style: context.text.bodySmall),
                                TextButton(
                                  onPressed: () => context.go(TRoutes.whRegister),
                                  child: const Text('تسجيل المستودع'),
                                ),
                              ],
                            ),

                            const Divider(height: AppSpacing.xl),

                            AppButton(
                              label: 'دخول كصيدلية',
                              icon: Icons.local_pharmacy_outlined,
                              variant: AppButtonVariant.outline,
                              onPressed: () => context.go(TRoutes.phLogin),
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
