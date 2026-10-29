import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// الحد الأدنى للطلبية — مُخزَّن محلياً حتى يُضاف الـ endpoint في الخادم.
class _MinOrderNotifier extends Notifier<double?> {
  @override
  double? build() => null;
  void set(double? v) => state = v;
}

final minOrderAmountProvider =
    NotifierProvider<_MinOrderNotifier, double?>(_MinOrderNotifier.new);

// إعداد الحد الأدنى للطلبية (Figma: إعدادات / الحد الأدنى للطلبية).
class WhMinOrderPage extends ConsumerStatefulWidget {
  const WhMinOrderPage({super.key});

  @override
  ConsumerState<WhMinOrderPage> createState() => _WhMinOrderPageState();
}

class _WhMinOrderPageState extends ConsumerState<WhMinOrderPage> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final current = ref.read(minOrderAmountProvider);
    if (current != null) _controller.text = current.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final text = _controller.text.trim();
    final amount = text.isEmpty ? null : double.tryParse(text);
    ref.read(minOrderAmountProvider.notifier).set(amount);
    AppSnackbar.success(context, 'تم حفظ الحد الأدنى للطلبية');
    Navigator.of(context).pop();
  }

  void _clear() {
    _controller.clear();
    ref.read(minOrderAmountProvider.notifier).set(null);
    AppSnackbar.success(context, 'تم إلغاء الحد الأدنى');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return Scaffold(
      appBar: const InnerTopBar(title: 'الحد الأدنى للطلبية'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.x3l),
          children: [
            Text(
              'حدّد الحد الأدنى لقيمة الطلبية التي يقبلها مستودعك. الصيدليات '
              'ترى هذا الحد عند تصفّح عروضك.',
              style: context.text.bodyMedium?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.x2l),
            AppTextField(
              controller: _controller,
              label: 'الحد الأدنى للطلبية',
              hint: 'مثال: 50000',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              suffix: Text('ل.س',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.tokens.hint)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // اختياري
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'أدخل رقماً صحيحاً';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'حفظ', onPressed: _save),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'إلغاء الحد الأدنى',
              variant: AppButtonVariant.outline,
              onPressed: _clear,
            ),
          ],
        ),
      ),
    );
  }
}
