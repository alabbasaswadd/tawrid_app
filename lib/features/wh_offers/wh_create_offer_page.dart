import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';
import 'package:tawrid_app/shared/widgets/multi_region_picker.dart';

// إنشاء عرض بيع — اختيار الأصناف يتم من أدوية المستودع المُضافة مسبقاً
// (wh_medicines_page.dart) فقط، لا كتابة حرّة ولا من الكاتالوج العام
// مباشرة.
class WhCreateOfferPage extends ConsumerStatefulWidget {
  const WhCreateOfferPage({super.key});

  @override
  ConsumerState<WhCreateOfferPage> createState() => _WhCreateOfferPageState();
}

class _OfferItemDraft {
  _OfferItemDraft(this.medicine)
      : unit = TextEditingController(text: 'علبة'),
        // الكمية المعروضة: سقف ما يستطيع الصيدلي طلبه من هذا الصنف.
        // كانت مثبّتة على ١ في الشيفرة فكان كل عرض يقول «المتاح: عبوة
        // واحدة» ولا يسمح بطلب أكثر — عرضٌ بلا معنى.
        quantity = TextEditingController(text: '100'),
        unitPrice = TextEditingController(),
        discount = TextEditingController(),
        bonus = TextEditingController();

  final WarehouseMedicine medicine;
  final TextEditingController unit;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController discount;
  final TextEditingController bonus;

  void dispose() {
    unit.dispose();
    quantity.dispose();
    unitPrice.dispose();
    discount.dispose();
    bonus.dispose();
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
  String _currency = 'SYP';
  List<TargetRegion> _targetRegions = [];
  bool _isPublicInRegion = false;
  final List<_OfferItemDraft> _items = [];
  bool _saving = false;

  // بونص على مستوى العرض كله = دواء مجاني (اختياري)
  WarehouseMedicine? _bonusMedicine;
  final _bonusQuantity = TextEditingController(text: '1');
  final _bonusUnit = TextEditingController(text: 'علبة');

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
      setState(() => _items.addAll(picked.map(_OfferItemDraft.new)));
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
                bonusPercentage: d.bonus.text.trim().isEmpty ? null : double.tryParse(d.bonus.text),
              ))
          .toList();

      await ref.read(salesOfferRepositoryProvider).createOffer(
            title: _title.text.trim(),
            description: _description.text.trim().isEmpty ? null : _description.text.trim(),
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            currency: _currency,
            targetRegions: _targetRegions,
            isPublicInRegion: _isPublicInRegion,
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
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان العرض'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'العملة', prefixIcon: Icon(Icons.payments_outlined)),
              items: const [
                DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
                DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _DatePickerField(label: 'يبدأ في', date: _startsAt, onTap: () => _pickDate(isStart: true))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _DatePickerField(label: 'ينتهي في', date: _expiresAt, onTap: () => _pickDate(isStart: false))),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('المنطقة المستهدفة (يمكن إضافة أكثر من محافظة/مدينة)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            MultiRegionPicker(
              regions: _targetRegions,
              onChanged: (v) => setState(() => _targetRegions = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('متاح لكل صيدليات المناطق المستهدفة'),
              subtitle: const Text('إيقافه يقصر العرض على الصيدليات المحددة'),
              value: _isPublicInRegion,
              onChanged: (v) => setState(() => _isPublicInRegion = v),
            ),
            // شروط الدفع صارت اختيارية لكل عرض بعد حذف «نوع العرض»
            ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _upfrontPercentage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'نسبة الدفع المقدَّم (%)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _paymentPeriodDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مدة السداد (أيام)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _consignmentTerms,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الشروط (اختياري)'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addMedicine,
                  icon: const Icon(Icons.add),
                  label: const Text('أضف دواء'),
                ),
              ],
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
                style: Theme.of(context).textTheme.titleSmall),
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
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: draft.bonus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'بونص % (اختياري)', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
