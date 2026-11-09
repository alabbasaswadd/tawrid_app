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

  /// عملة تسعير المستودع — تُحمَّل من إعداداته لا من ثابتِ منصّة، فكل
  /// مبلغ في هذه الشاشة (والحدّ الأدنى نفسه) بها.
  String _currency = 'SYP';

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
        _currency = settings.pricingCurrency;
        _controller.text = settings.minimumOrderAmount == null
            ? ''
            : formatAmount(
                settings.minimumOrderAmount!,
                settings.pricingCurrency,
              ).replaceAll(',', '');
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
          .update(
            minimumOrderAmount: value,
            pricingCurrency: _currency,
          );
      if (!mounted) return;
      setState(() => _currency = saved.pricingCurrency);
      AppSnackbar.success(
        context,
        saved.minimumOrderAmount == null
            ? 'أُلغي الحدّ الأدنى — تُقبل أي قيمة'
            : 'حُفظ الحدّ الأدنى: '
                  '${formatMoneyWith(saved.minimumOrderAmount!, saved.pricingCurrency)}',
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
          ? const AppDetailSkeleton()
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

                // عملة التسعير: إعداد بائع كالحدّ الأدنى. يرفض الخادم
                // تبديلها ما دام هناك عرض بيع فعّال — فأسعار «أدويتي»
                // أرقامٌ بلا عملة مخزَّنة معها، وتبديلها يُعيد تسميتها كلها.
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'عملة التسعير',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
                    DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _currency = v ?? _currency),
                ),
                const SizedBox(height: 6),
                Text(
                  'عملة كل أسعارك: «أدويتي» وعروض البيع وعروض التسعير والحدّ '
                  'الأدنى. لا يمكن تبديلها وعندك عرض بيع فعّال — ألغِ '
                  'العروض الفعّالة أو انتظر انتهاءها، ثم راجع أسعارك بعد '
                  'التبديل.',
                  style: context.text.labelSmall?.copyWith(color: tk.hint),
                ),

                const SizedBox(height: AppSpacing.x2l),
                AppTextField(
                  controller: _controller,
                  label: 'الحدّ الأدنى للطلب (${currencySymbol(_currency)})',
                  hint: _currency == 'SYP' ? '100000' : '50',
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
                  '${formatMoneyWith(_currency == 'SYP' ? 60000 : 30, _currency)} '
                  'إن كان حدّك '
                  '${formatMoneyWith(_currency == 'SYP' ? 100000 : 50, _currency)} '
                  '— سيُطلب من الصيدلي إضافة أصناف لبلوغ الحدّ.',
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
