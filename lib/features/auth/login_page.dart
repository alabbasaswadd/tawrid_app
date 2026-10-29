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
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// دخول الصيدلية — بالحقول التي يطلبها الباك إند: البريد وكلمة المرور.
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
      final data = await api.post(
        ApiEndpoints.phLogin,
        data: {'email': _email.text.trim(), 'password': _password.text},
      ) as Map<String, dynamic>;
      await ref
          .read(pharmacySessionProvider.notifier)
          .establish(
            token: data['token'] as String,
            // الباك يُرجع tenantId لا userId — نستخدمه كمعرّف للمستخدم
            userId: (data['userId'] ?? data['tenantId']) as String?,
            tenantId: data['tenantId'] as String?,
            accountStatus: AccountStatus.fromApi(data['accountStatus']),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.x2l,
          ),
          child: CenteredContent(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  const _BrandHeader(subtitle: 'المنصة الذكية للتوريد الدوائي'),
                  const SizedBox(height: AppSpacing.x3l),

                  Text('دخول الصيدلية', style: context.text.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'أدخل بيانات حسابك للمتابعة',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    controller: _email,
                    label: 'البريد الإلكتروني',
                    hint: 'example@domain.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'البريد مطلوب' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _password,
                    label: 'كلمة المرور',
                    hint: 'أدخل كلمة المرور',
                    obscure: true,
                    onSubmitted: (_) => _login(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  AppButton(
                    label: 'دخول',
                    loading: _loading,
                    onPressed: _loading ? null : _login,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ليس لديك حساب؟', style: context.text.bodySmall),
                      AppButton(
                        label: 'إنشاء حساب',
                        variant: AppButtonVariant.text,
                        fullWidth: false,
                        onPressed: () => context.push(TRoutes.phRegister),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton(
                    label: 'دخول كمستودع',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.go(TRoutes.whLogin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// شعار توريد + الاسم + سطر تعريفي — ترويسة شاشات المصادقة.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.asset(
            'assets/images/logo.jpg',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('توريد', style: context.text.displayMedium),
        Text(subtitle, style: context.text.bodySmall),
      ],
    );
  }
}
