import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/repositories/warehouse_settings_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// إعدادات الطلبيات (Figma: المستودع / إعدادات الطلبيات).
//
// الحدّ الأدنى إعداد **بائع**: يضبطه كل مستودع لنفسه ولا تفرضه المنصّة ولا
// الصيدلية. الخادم يرفض الطلبيات الأقل منه عند إتمام الصيدلي لطلبه، وسلّته
// تعرض له كم ينقص قبل ذلك.
class WhOrderSettingsPage extends ConsumerStatefulWidget {
  const WhOrderSettingsPage({super.key});

  @override
  ConsumerState<WhOrderSettingsPage> createState() => _WhOrderSettingsPageState();
}

class _WhOrderSettingsPageState extends ConsumerState<WhOrderSettingsPage> {
  final _controller = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ref.read(warehouseSettingsRepositoryProvider).get();
      if (!mounted) return;
      setState(() {
        _controller.text = settings.minimumOrderAmount == null
            ? ''
            : settings.minimumOrderAmount!.toStringAsFixed(0);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final raw = _controller.text.trim().replaceAll(',', '');
    double? value;
    if (raw.isNotEmpty) {
      value = double.tryParse(raw);
      if (value == null || value <= 0) {
        AppSnackbar.error(
          context,
          'أدخل مبلغاً أكبر من صفر، أو اترك الحقل فارغاً لإلغاء الحدّ',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(warehouseSettingsRepositoryProvider)
          .update(minimumOrderAmount: value);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        saved.minimumOrderAmount == null
            ? 'أُلغي الحدّ الأدنى — تُقبل أي قيمة'
            : 'حُفظ الحدّ الأدنى: '
                  '${formatMoneyWith(saved.minimumOrderAmount!, kPlatformCurrency)}',
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return Scaffold(
      appBar: const InnerTopBar(title: 'إعدادات الطلبيات'),
      body: _loading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.x3l,
              ),
              children: [
                Text(
                  'حدّد حدّاً أدنى لقيمة الطلبية الواحدة التي تصلك من '
                  'الصيدليات — الطلبيات الأقل منه تُرفض تلقائياً عند إتمام '
                  'الصيدلي لطلبه. اتركه فارغاً لقبول أي قيمة.',
                  style: context.text.bodyMedium,
                ),

                const SizedBox(height: AppSpacing.x2l),
                AppTextField(
                  controller: _controller,
                  label: 'الحدّ الأدنى للطلب (${currencySymbol(kPlatformCurrency)})',
                  hint: '100000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 6),
                Text(
                  'اتركه فارغاً لعدم فرض حدّ أدنى',
                  style: context.text.labelSmall?.copyWith(color: tk.hint),
                ),

                const SizedBox(height: AppSpacing.lg),
                Text(
                  'مثال: لن تصل طلبية بقيمة '
                  '${formatMoneyWith(60000, kPlatformCurrency)} إن كان حدّك '
                  '${formatMoneyWith(100000, kPlatformCurrency)} — سيُطلب من '
                  'الصيدلي إضافة أصناف لبلوغ الحدّ.',
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  boxShadow: context.tokens.navShadow,
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                child: AppButton(
                  label: 'حفظ',
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
    );
  }
}
