import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// أدوية مستودعي (Figma: المستودع / أدوية مستودعي).
//
// قائمة أصناف لا مخزون بكميات. لكل صنف **سعر اختياري**: الصنف المسعَّر يظهر
// للصيدليات في البحث المقارن كـ«تسعير مباشر»، وغير المسعَّر يبقى بياناً
// تعريفياً تُبنى عليه العروض فقط. الكميات تبقى داخل كل عرض بيع.
class WhMedicinesPage extends ConsumerStatefulWidget {
  const WhMedicinesPage({super.key});

  @override
  ConsumerState<WhMedicinesPage> createState() => _WhMedicinesPageState();
}

class _WhMedicinesPageState extends ConsumerState<WhMedicinesPage> {
  List<WarehouseMedicine>? _items;
  bool _loading = true;
  String? _error;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(warehouseMedicineRepositoryProvider)
          .getMine(search: _query, limit: 50);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    // نصف ثانية: كتابة اسم دواء عربي لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _query = v);
      _load(silent: true);
    });
  }

  Future<void> _remove(WarehouseMedicine m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة من أدويتي'),
        content: Text(
            'سيُزال «${m.displayName}» من قائمة أدوية مستودعك. لا يؤثر ذلك '
            'في العروض المنشورة التي تضمّه.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(warehouseMedicineRepositoryProvider).remove(m.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُزيل الدواء من قائمتك');
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  // تحرير السعر في حوار صغير: الحقل وحده هو القرار ولا يستحق شاشة.
  // إفراغ الحقل يسحب السعر — يختفي الصنف من بحث الصيدليات ويبقى في قائمتك.
  Future<void> _editPrice(WarehouseMedicine m) async {
    final controller = TextEditingController(
      text: m.price == null ? '' : m.price!.toStringAsFixed(0),
    );

    final result = await showDialog<_PriceResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.price == null ? 'إضافة سعر' : 'تعديل السعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.displayName, style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: controller,
              label: 'سعر الوحدة (${currencySymbol(kPlatformCurrency)})',
              hint: '12500',
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'اتركه فارغاً ليعود السعر إلى التقديري (٧٤٪ من سعر '
              'المستهلك في النشرة).',
              style: Theme.of(ctx).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim().replaceAll(',', '');
              if (raw.isEmpty) {
                Navigator.pop(ctx, const _PriceResult(null));
                return;
              }
              final value = double.tryParse(raw);
              if (value == null || value <= 0) {
                AppSnackbar.error(ctx, 'أدخل سعراً أكبر من صفر');
                return;
              }
              Navigator.pop(ctx, _PriceResult(value));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) return;

    try {
      await ref
          .read(warehouseMedicineRepositoryProvider)
          .setPrice(m.id, result.value);
      if (!mounted) return;
      AppSnackbar.success(
        context,
        result.value == null ? 'سُحب سعر الصنف' : 'حُفظ السعر',
      );
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  // الماسح حقيقي (mobile_scanner): يُعيد الرمز نصاً فنمرّره إلى البحث
  // نفسه — الباركود مجرّد طريقة أسرع لكتابة ما يُبحث عنه.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    // لا حقل نصّي مرتبط — يُمرَّر الرمز مباشرة إلى البحث.
    _onSearchChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أدوية مستودعي'),
        actions: [
          // زر الكتالوج العام: حدٌّ بلون العلامة — ثانوي لا رئيسي.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: cs.primary)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () async {
                  await context.push(TRoutes.whMedicineCatalog);
                  if (mounted) await _load(silent: true);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('الكتالوج العام',
                          style: context.text.bodySmall
                              ?.copyWith(color: cs.primary)),
                      const SizedBox(width: 6),
                      AppIcon(AppIcons.package, size: 15, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final tk = context.tokens;
    final items = _items ?? const <WarehouseMedicine>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
          child: AppSearchBar(
            hint: 'ابحث في أصناف المخزون…',
            onChanged: _onSearchChanged,
            onScanTap: _scanBarcode,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _loading
                  ? 'جارٍ التحميل…'
                  : '${items.length} ${items.length == 1 ? 'دواء' : 'دواءً'} في مستودعك',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
          ),
        ),

        Expanded(child: _buildList(items)),
      ],
    );
  }

  Widget _buildList(List<WarehouseMedicine> items) {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.medication_outlined,
            message: _query.trim().isNotEmpty
                ? 'لا دواء يطابق بحثك في أدويتك'
                : 'لا أدوية بعد — أضفها من «الكتالوج العام» لتبني عليها عروضك',
          ),
        ],
      );
    }

    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MedicineCard(
              medicine: m,
              onRemove: () => _remove(m),
              onEditPrice: () => _editPrice(m),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        // توضيح ما تعنيه القائمة فعلاً — ليست مخزوناً بكميات وأسعار.
        Text(
          'كل صنف في قائمتك يظهر للصيدليات في البحث المقارن. ما لم تحدّد له '
          'سعراً يُحتسب سعره ٧٤٪ من سعر المستهلك في النشرة الوطنية، '
          'ويبقى سعرك اليدوي — متى أدخلته — هو المعتمد. الكميات تُحدَّد '
          'داخل كل عرض بيع.',
          style: context.text.labelSmall?.copyWith(color: tk.hint),
        ),
      ],
    );
  }
}

/// نتيجة حوار السعر — تميّز «أُلغي الحوار» (null) عن «سُحب السعر» (قيمة
/// بداخلها null)، وهما قراران مختلفان لا يصحّ خلطهما.
class _PriceResult {
  const _PriceResult(this.value);
  final double? value;
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onRemove,
    required this.onEditPrice,
  });

  final WarehouseMedicine medicine;
  final VoidCallback onRemove;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final m = medicine;

    final spec = [
      if (m.genericName.isNotEmpty) m.genericName,
      m.dosageForm.label,
      if (m.manufacturerName.isNotEmpty) m.manufacturerName,
    ].join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.displayName,
                        style: context.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(spec,
                        style:
                            context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (m.sakoCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('كود ساكو: ${m.sakoCode}',
                          style: context.text.labelSmall
                              ?.copyWith(color: tk.hint)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // السعر أولاً: هو ما تراه الصيدليات. وحين لا يُدخله
                  // المستودع يدوياً يُشتقّ من سعر المستهلك (٧٤٪) — فلا
                  // يظنّ صنفه بلا سعر بينما يُباع فعلاً بسعر مشتقّ.
                  if (m.effectivePrice != null)
                    Text(
                      formatMoneyWith(m.effectivePrice!, kPlatformCurrency),
                      style: context.priceStyle,
                    )
                  else
                    Text(
                      'لا سعر ولا نشرة',
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                  if (m.isDerivedPrice)
                    Text(
                      'تقديري (٧٤٪ من سعر المستهلك)',
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onEditPrice,
                        style: _denseButton,
                        child: Text(
                          m.price == null ? 'حدّد سعراً' : 'تعديل',
                          style:
                              context.text.bodySmall?.copyWith(color: cs.primary),
                        ),
                      ),
                      TextButton(
                        onPressed: onRemove,
                        style: _denseButton,
                        child: Text(
                          'إزالة',
                          style:
                              context.text.bodySmall?.copyWith(color: cs.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // إجراءان متجاوران داخل بطاقة — الحشوة الافتراضية تجعلهما يزاحمان النص.
  static final ButtonStyle _denseButton = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
