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
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// دخول المستودع — بالحقول التي يطلبها الباك إند:
// اسم المستخدم أو البريد (login) وكلمة المرور.
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
      final data = await api.post(
        ApiEndpoints.whLogin,
        data: {'login': _username.text.trim(), 'password': _password.text},
      ) as Map<String, dynamic>;
      await ref
          .read(warehouseSessionProvider.notifier)
          .establish(
            token: data['token'] as String,
            warehouseUserId: data['warehouseUserId'] as String?,
            warehouseId: data['warehouseId'] as String?,
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
                  Column(
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
                      Text('بوابة المستودع', style: context.text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x3l),

                  Text('دخول المستودع', style: context.text.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'أدخل بيانات حساب المستودع',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    controller: _username,
                    label: 'اسم المستخدم أو البريد',
                    hint: 'أدخل اسم المستخدم أو البريد',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
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
                      Text('مستودع جديد؟', style: context.text.bodySmall),
                      AppButton(
                        label: 'تسجيل المستودع',
                        variant: AppButtonVariant.text,
                        fullWidth: false,
                        onPressed: () => context.go(TRoutes.whRegister),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.xl),

                  AppButton(
                    label: 'دخول كصيدلية',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.go(TRoutes.phLogin),
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
