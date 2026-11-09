import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/bonus_tier.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/repositories/warehouse_settings_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/multi_region_picker.dart';

// إنشاء عرض بيع — اختيار الأصناف يتم من أدوية المستودع المُضافة مسبقاً
// (wh_medicines_page.dart) فقط، لا كتابة حرّة ولا من الكاتالوج العام
// مباشرة.
class WhCreateOfferPage extends ConsumerStatefulWidget {
  const WhCreateOfferPage({super.key});

  @override
  ConsumerState<WhCreateOfferPage> createState() => _WhCreateOfferPageState();
}

/// شريحة بونص قيد التحرير: «اشترِ [buy] واحصل على [free] مجاناً».
class _BonusTierDraft {
  _BonusTierDraft()
      : buy = TextEditingController(),
        free = TextEditingController();

  final TextEditingController buy;
  final TextEditingController free;

  bool get isEmpty => buy.text.trim().isEmpty && free.text.trim().isEmpty;

  BonusTier? toTier() {
    final b = double.tryParse(buy.text.trim());
    final f = double.tryParse(free.text.trim());
    if (b == null || f == null || b <= 0 || f <= 0) return null;
    return BonusTier(buyQuantity: b, freeQuantity: f, label: '');
  }

  void dispose() {
    buy.dispose();
    free.dispose();
  }
}

class _OfferItemDraft {
  _OfferItemDraft(this.medicine, {double? defaultPrice, String currency = 'SYP'})
      : unit = TextEditingController(text: 'علبة'),
        quantity = TextEditingController(text: '100'),
        unitPrice = TextEditingController(
          text: defaultPrice != null && defaultPrice > 0
              // بمنازل العملة: تقريبُ 2.25 إلى «2» كان يُسقط سعر العرض
              // الافتراضي على رقم آخر قبل أن يراه المستودع.
              ? formatAmount(defaultPrice, currency).replaceAll(',', '')
              : '',
        ),
        discount = TextEditingController();

  final WarehouseMedicine medicine;
  final TextEditingController unit;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController discount;

  /// سلّم البونص لهذا الصنف — «(10+5) (5+2) (3+1)». فارغ = لا بونص.
  final List<_BonusTierDraft> bonusTiers = [];

  /// الشرائح الصالحة وحدها تُرسَل؛ الصفّ الفارغ يُهمَل بلا خطأ.
  List<BonusTier> validTiers() =>
      bonusTiers.map((t) => t.toTier()).whereType<BonusTier>().toList();

  /// صفٌّ مملوء جزئياً (كمية بلا مقابلها) — خطأُ إدخال لا إغفال.
  bool get hasIncompleteTier =>
      bonusTiers.any((t) => !t.isEmpty && t.toTier() == null);

  /// كميتا شراء متساويتان في سلّم واحد تناقضٌ لا خيار — والخادم يرفضه.
  bool get hasDuplicateTier {
    final buys = validTiers().map((t) => t.buyQuantity).toList();
    return buys.toSet().length != buys.length;
  }

  void dispose() {
    unit.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    for (final t in bonusTiers) {
      t.dispose();
    }
  }
}

class _WhCreateOfferPageState extends ConsumerState<WhCreateOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _upfrontPercentage = TextEditingController();
  final _paymentPeriodDays = TextEditingController();
  final _consignmentTerms = TextEditingController();

  DateTime _startsAt = DateTime.now();
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));

  /// نوع العرض. الثابت يُرسَل بلا تاريخ انتهاء — وهو ما يجعله ثابتاً في
  /// الخادم (لا حقلَ «نوع» منفصلاً يناقض التاريخ).
  SalesOfferKind _kind = SalesOfferKind.timeLimited;

  /// عملة تسعير المستودع — تُعرَض ولا تُختار: الخادم يفرضها ويتجاهل أي
  /// عملة في جسم الطلب، فمنتقي عملةٍ هنا كان يَعِد بتحكّمٍ لا وجود له.
  /// تبديلها من «إعدادات الطلبيات».
  String _currency = 'SYP';
  List<TargetRegion> _targetRegions = [];
  final List<_OfferItemDraft> _items = [];
  bool _saving = false;

  // بونص على مستوى العرض كله = دواء مجاني (اختياري)
  WarehouseMedicine? _bonusMedicine;
  final _bonusQuantity = TextEditingController(text: '1');
  final _bonusUnit = TextEditingController(text: 'علبة');

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    try {
      final settings = await ref.read(warehouseSettingsRepositoryProvider).get();
      if (!mounted) return;
      setState(() => _currency = settings.pricingCurrency);
    } catch (_) {
      // تعذّر جلب العملة لا يمنع إنشاء العرض: الخادم يفرضها على أي حال،
      // وكل ما يضيع هنا هو دقّة الرمز المعروض بجانب الحقول.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _upfrontPercentage.dispose();
    _paymentPeriodDays.dispose();
    _consignmentTerms.dispose();
    _bonusQuantity.dispose();
    _bonusUnit.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startsAt : _expiresAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _addMedicine() async {
    final picked = await showModalBottomSheet<List<WarehouseMedicine>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MedicinePickerSheet(
        alreadyPicked: _items.map((d) => d.medicine.id).toSet(),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _items.addAll(picked.map((m) => _OfferItemDraft(
            m,
            // السعر المقترح هو سعر بيع المستودع نفسه: اليدوي إن حدّده،
            // وإلا ٧٤٪ من سعر المستهلك في النشرة. هو الرقم الذي تراه
            // الصيدليات في البحث المقارن، فيبدأ العرض منه بدل حقل فارغ —
            // والمستودع يعدّله إن أراد سعراً خاصاً بالعرض.
            defaultPrice: m.effectivePrice,
          ))));
    }
  }

  Future<void> _pickBonusMedicine() async {
    final picked = await showModalBottomSheet<List<WarehouseMedicine>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _MedicinePickerSheet(alreadyPicked: {}, single: true),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _bonusMedicine = picked.first);
    }
  }

  void _removeItem(_OfferItemDraft draft) {
    setState(() {
      _items.remove(draft);
      draft.dispose();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_items.isEmpty) {
      AppSnackbar.error(context, 'أضف دواءً واحداً على الأقل');
      return;
    }
    if (_targetRegions.isEmpty) {
      AppSnackbar.error(context, 'أضف منطقة مستهدفة واحدة على الأقل (محافظة/مدينة)');
      return;
    }

    // سلالم البونص: يُرفضان هنا برسالة تسمّي الصنف بدل أن يردّهما الخادم
    // برسالة عامة بعد رحلة شبكة.
    final incomplete = _items.where((d) => d.hasIncompleteTier).toList();
    if (incomplete.isNotEmpty) {
      AppSnackbar.error(
        context,
        'أكمِل شريحة البونص في «${incomplete.first.medicine.displayName}» — '
        'كلّ شريحة تحتاج كمية شراء وكمية مجانية، كلتاهما أكبر من صفر.',
      );
      return;
    }

    final duplicate = _items.where((d) => d.hasDuplicateTier).toList();
    if (duplicate.isNotEmpty) {
      AppSnackbar.error(
        context,
        'في «${duplicate.first.medicine.displayName}» شريحتان بنفس كمية '
        'الشراء — اجعل لكل كمية شريحةً واحدة.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final items = _items
          .map((d) => SalesOfferItem(
                id: '',
                medicineName: d.medicine.displayName,
                catalogItemId: d.medicine.catalogItemId,
                quantity: double.tryParse(d.quantity.text.trim()) ?? 1,
                unit: d.unit.text.trim(),
                unitPrice: double.tryParse(d.unitPrice.text) ?? 0,
                discountPercentage:
                    d.discount.text.trim().isEmpty ? null : double.tryParse(d.discount.text),
                bonusTiers: d.validTiers(),
              ))
          .toList();

      await ref.read(salesOfferRepositoryProvider).createOffer(
            title: _title.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            startsAt: _startsAt,
            expiresAt:
                _kind == SalesOfferKind.standing ? null : _expiresAt,
            targetRegions: _targetRegions,
            // الحقل مُبقًى في الطلب لأن أمر الخادم يطلبه، لكنه لا أثر له:
            // حارس الرؤية يتجاهله ويعرض العرض لكل صيدلية تغطّيها مناطقه
            // المستهدَفة. إرسال true يطابق السلوك الفعلي بدل مفتاح يوهم
            // المستخدم بتحكّمٍ لا يملكه.
            isPublicInRegion: true,
            upfrontPercentage: _upfrontPercentage.text.trim().isEmpty
                ? null
                : double.tryParse(_upfrontPercentage.text),
            paymentPeriodDays: _paymentPeriodDays.text.trim().isEmpty
                ? null
                : int.tryParse(_paymentPeriodDays.text),
            consignmentTerms:
                _consignmentTerms.text.trim().isEmpty ? null : _consignmentTerms.text.trim(),
            items: items,
            bonusMedicineName: _bonusMedicine?.displayName,
            bonusMedicineCatalogItemId: _bonusMedicine?.catalogItemId,
            bonusMedicineQuantity:
                _bonusMedicine == null ? null : (double.tryParse(_bonusQuantity.text) ?? 1),
            bonusMedicineUnit: _bonusMedicine == null ? null : _bonusUnit.text.trim(),
          );

      if (mounted) {
        // الخادم يُنشئ العرض بحالة «مسودة» لا «منشور»، فقول «تم الإنشاء»
        // وحده يترك المستودع ينتظر طلبيات على عرض لا تراه أي صيدلية.
        AppSnackbar.success(
            context, 'حُفظ العرض كمسودة — اضغط «نشر» ليصل الصيدليات');
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عرض بيع جديد')),
      // SingleChildScrollView لا ListView: الأخيرة تُزيل الحقول الخارجة عن
      // الشاشة من الشجرة، فتُلغى تسجيلها في الـForm ويتخطّاها `validate()`
      // ويُرجع true. كان الأثر أن عرضاً بعنوان فارغ يُرسَل ويردّه الخادم
      // بـ400 — الحقل كان قد اختفى حين وصل المستخدم إلى زر الحفظ.
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // النموذج مقسوم بطاقات على خلفية الصفحة بدل صفحة حقول بيضاء
            // متصلة: الأقسام تُقرأ وتُراجَع، والألوان تأتي من الثيم كما في
            // بقية الشاشات بدل أبيض صريح.
            _Section(
              title: 'بيانات العرض',
              children: [
                AppTextField(
                  controller: _title,
                  label: 'عنوان العرض',
                  hint: 'مثال: حزمة المضادات الحيوية',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _description,
                  label: 'وصف (اختياري)',
                  hint: 'ما يميّز هذا العرض',
                ),
                const SizedBox(height: AppSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'العملة',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  child: Text(
                    '${currencyName(_currency)} (${currencySymbol(_currency)})',
                    style: context.text.bodyMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'عملة أسعارك كلها — تُبدَّل من «إعدادات الطلبيات» لا لكل '
                  'عرض على حدة.',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.tokens.hint),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('نوع العرض', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final k in SalesOfferKind.values)
                      AppFilterChip(
                        label: k.label,
                        selected: _kind == k,
                        onTap: () => setState(() => _kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _kind == SalesOfferKind.standing
                      ? 'عرض ثابت: يبقى سارياً حتى تُلغيه بنفسك — كنشرة '
                            'أسعارٍ دائمة، بلا تاريخ انتهاء.'
                      : 'عرض لفترة محدّدة: ينتهي تلقائياً عند تاريخه '
                            'ويختفي عن الصيدليات.',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.tokens.hint),
                ),

                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _DatePickerField(label: 'يبدأ في', date: _startsAt, onTap: () => _pickDate(isStart: true))),
                    if (_kind == SalesOfferKind.timeLimited) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _DatePickerField(label: 'ينتهي في', date: _expiresAt, onTap: () => _pickDate(isStart: false))),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'من يرى العرض',
              children: [
                Text('المنطقة المستهدفة (يمكن إضافة أكثر من محافظة/مدينة)',
                    style: context.text.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                MultiRegionPicker(
                  regions: _targetRegions,
                  onChanged: (v) => setState(() => _targetRegions = v),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'يراه كل صيدلية تقع ضمن المناطق المختارة.',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.tokens.hint),
                ),
              ],
            ),

            // شروط الدفع صارت اختيارية لكل عرض بعد حذف «نوع العرض»
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'شروط الدفع (اختيارية)',
              children: [
                AppTextField(
                  controller: _upfrontPercentage,
                  label: 'نسبة الدفع المقدَّم (%)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _paymentPeriodDays,
                  label: 'مدة السداد (أيام)',
                  hint: '30',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _consignmentTerms,
                  label: 'الشروط (اختياري)',
                  hint: 'تفاصيل إضافية للاتفاق',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف', style: context.text.titleLarge),
                TextButton.icon(
                  onPressed: _addMedicine,
                  icon: const Icon(Icons.add),
                  label: const Text('أضف دواء'),
                ),
              ],
            ),
            // الرقم المقترح ليس التزاماً: نقول من أين جاء حتى يعرف المستودع
            // ما الذي يعدّله حين يعدّله.
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm, right: 2),
                child: Text(
                  'سعر الوحدة مقترح من سعر بيعك للصنف (٧٤٪ من سعر المستهلك '
                  'ما لم تحدّد سعراً) — عدّله كما تشاء.',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.tokens.hint),
                ),
              ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: EmptyState(message: 'لم تُضف أصناف بعد', icon: Icons.medication_outlined),
              )
            else
              ..._items.map((draft) => _OfferItemCard(
                    draft: draft,
                    onRemove: () => _removeItem(draft),
                  )),

            const SizedBox(height: AppSpacing.lg),
            Text('بونص العرض (دواء مجاني — اختياري)',
                style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (_bonusMedicine == null)
              OutlinedButton.icon(
                onPressed: _pickBonusMedicine,
                icon: const Icon(Icons.card_giftcard_outlined),
                label: const Text('إضافة دواء بونص'),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.tokens.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.tokens.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.card_giftcard, size: 18, color: context.tokens.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_bonusMedicine!.displayName,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: context.colors.error),
                          onPressed: () => setState(() => _bonusMedicine = null),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bonusQuantity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'كمية البونص', isDense: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TextFormField(
                            controller: _bonusUnit,
                            decoration: const InputDecoration(labelText: 'الوحدة', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'نشر العرض',
              icon: Icons.check_circle_outline,
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text('${date.year}/${date.month}/${date.day}'),
      ),
    );
  }
}

class _OfferItemCard extends StatelessWidget {
  const _OfferItemCard({required this.draft, required this.onRemove});
  final _OfferItemDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(draft.medicine.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.error),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'الكمية المتاحة', isDense: true),
                    validator: (v) {
                      final q = double.tryParse((v ?? '').trim());
                      // الخادم يشترط Quantity > 0، فنمنع الرفض هنا بدل
                      // ترك المستخدم يصطدم بـ400 بعد ملء النموذج كاملاً.
                      if (q == null || q <= 0) return 'كمية غير صالحة';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: draft.unit,
                    decoration:
                        const InputDecoration(labelText: 'الوحدة', isDense: true),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.unitPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الوحدة', isDense: true),
                    validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: draft.discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'حسم % (اختياري)', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _BonusTiersEditor(draft: draft),
          ],
        ),
      ),
    );
  }
}

// ── محرّر شرائح البونص ─────────────────────────────────────────────────
//
// صنفٌ واحد قد يحمل سلّماً كاملاً — «(10+5) (5+2) (3+1)» شائعة في نشرات
// المستودعات — فحقل «بونص %» الواحد كان يُسقط السلّم على رقم. والشرائح
// تُركَّب عند الشراء: الكمية 25 أمام (10+5) و(5+2) تستحقّ 12 مجاناً.
class _BonusTiersEditor extends StatefulWidget {
  const _BonusTiersEditor({required this.draft});

  final _OfferItemDraft draft;

  @override
  State<_BonusTiersEditor> createState() => _BonusTiersEditorState();
}

class _BonusTiersEditorState extends State<_BonusTiersEditor> {
  void _add() => setState(() => widget.draft.bonusTiers.add(_BonusTierDraft()));

  void _removeAt(int index) =>
      setState(() => widget.draft.bonusTiers.removeAt(index).dispose());

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final tiers = widget.draft.bonusTiers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'شرائح البونص (اختياري)',
                style: context.text.labelMedium,
              ),
            ),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة شريحة'),
            ),
          ],
        ),
        if (tiers.isEmpty)
          Text(
            'مثال: «اشترِ 10 واحصل على 5» — أضف شريحةً لكل درجة في سلّمك.',
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
        for (var i = 0; i < tiers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: tiers[i].buy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'اشترِ', isDense: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: tiers[i].free,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'واحصل مجاناً', isDense: true),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeAt(i),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'حذف الشريحة',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ورقة سفلية لاختيار دواء من قائمة أدوية المستودع المُضافة مسبقاً فقط —
// جوهر الطلب: لا كتابة حرّة ولا من الكاتالوج مباشرة.
class _MedicinePickerSheet extends ConsumerStatefulWidget {
  const _MedicinePickerSheet({required this.alreadyPicked, this.single = false});
  final Set<String> alreadyPicked;
  final bool single;

  @override
  ConsumerState<_MedicinePickerSheet> createState() => _MedicinePickerSheetState();
}

class _MedicinePickerSheetState extends ConsumerState<_MedicinePickerSheet> {
  final _search = TextEditingController();
  final Set<String> _selected = {};
  List<WarehouseMedicine>? _medicines;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(warehouseMedicineRepositoryProvider).getMine();
      setState(() {
        _medicines = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.single ? 'اختر دواء البونص' : 'اختر أدوية من مستودعك',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'بحث...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildList(scrollController)),
              if (!widget.single && _selected.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(
                      context,
                      (_medicines ?? []).where((m) => _selected.contains(m.id)).toList()),
                  child: Text('إضافة (${_selected.length})'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final query = _search.text.trim();
    final available = (_medicines ?? [])
        .where((m) => !widget.alreadyPicked.contains(m.id))
        .where((m) => query.isEmpty || m.displayName.contains(query) || m.genericName.contains(query))
        .toList();

    if (available.isEmpty) {
      return const EmptyState(
        message: 'لا توجد أدوية متاحة — أضف أدوية إلى مستودعك أولاً من صفحة "أدويتي"',
        icon: Icons.medication_outlined,
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: available.length,
      itemBuilder: (context, index) {
        final m = available[index];
        final selected = _selected.contains(m.id);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (widget.single) {
              Navigator.pop(context, [m]);
            } else {
              setState(() => selected ? _selected.remove(m.id) : _selected.add(m.id));
            }
          },
          child: MedicineListTile(
            displayName: m.displayName,
            genericName: m.genericName,
            manufacturerName: m.manufacturerName,
            dosageForm: m.dosageForm,
            strength: m.strength,
            trailing: widget.single
                ? Icon(Icons.chevron_left, color: context.tokens.hint)
                : Icon(selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: selected ? context.colors.primary : context.tokens.hint),
          ),
        );
      },
    );
  }
}

// قسم في نموذج العرض: عنوان فوق بطاقة من نظام التصميم. الخلفية والحدّ
// والظل من الثيم (AppCard) لا من أبيض صريح، فيتبع الوضعين الفاتح والداكن.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm, right: 2),
          child: Text(title, style: context.text.titleSmall),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
