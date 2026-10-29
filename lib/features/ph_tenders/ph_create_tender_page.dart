import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// صنف مختار في الطلب — اسم من الكتالوج وكمية يحدّدها الصيدلي.
class _DraftItem {
  _DraftItem({required this.catalogItem, required this.quantity});

  final MedicineCatalogItem catalogItem;
  int quantity;

  TenderItem toTenderItem() => TenderItem(
        id: '',
        medicineName: catalogItem.displayName,
        catalogItemId: catalogItem.id,
        quantity: quantity.toDouble(),
        unit: 'عبوة',
      );
}

// إنشاء طلب تسعير (Figma: الصيدلي / إنشاء طلب تسعير).
//
// الأصناف تُختار من الكتالوج المركزي لا بالكتابة الحرّة: اسم مكتوب بخطّ
// اليد لا يطابق ما في مخزون المستودع، فيصعب على المستودع تسعيره. الاختيار
// من الكتالوج يربط الصنف بـ catalogItemId فيعرف الطرفان أنه الدواء نفسه.
class PhCreateTenderPage extends ConsumerStatefulWidget {
  const PhCreateTenderPage({super.key});

  @override
  ConsumerState<PhCreateTenderPage> createState() => _PhCreateTenderPageState();
}

class _PhCreateTenderPageState extends ConsumerState<PhCreateTenderPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final List<_DraftItem> _items = [];
  late DateTime _expiresAt = _defaultDeadline();
  bool _saving = false;

  // المهلة الافتراضية: بعد ثلاثة أيام السادسة مساءً. الخادم يشترط تاريخاً
  // مستقبلياً، والساعة جزء من المهلة لا تفصيلة شكلية.
  static DateTime _defaultDeadline() {
    final d = DateTime.now().add(const Duration(days: 3));
    return DateTime(d.year, d.month, d.day, 18);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt.isAfter(now) ? _expiresAt : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );
    if (!mounted) return;

    setState(() => _expiresAt = DateTime(date.year, date.month, date.day,
        time?.hour ?? _expiresAt.hour, time?.minute ?? _expiresAt.minute));
  }

  Future<void> _pickItems() async {
    final picked = await showModalBottomSheet<List<_DraftItem>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickItemsSheet(already: _items),
    );
    if (picked == null) return;
    setState(() {
      _items
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _submit({required bool asDraft}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_items.isEmpty) {
      AppSnackbar.error(context, 'أضف صنفاً واحداً على الأقل');
      return;
    }
    // المسودة أيضاً تحتاج مهلةً مستقبلية: الخادم يرفض النشر بمهلة منتهية،
    // فالسماح بحفظها هنا يؤجّل الخطأ إلى لحظة النشر بلا فائدة.
    if (!_expiresAt.isAfter(DateTime.now())) {
      AppSnackbar.error(context, 'اختر مهلة في المستقبل');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).createTender(
            title: _title.text.trim(),
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            expiresAt: _expiresAt,
            items: _items.map((d) => d.toTenderItem()).toList(),
            asDraft: asDraft,
          );
      if (!mounted) return;
      AppSnackbar.success(
          context,
          asDraft
              ? 'حُفظت المسودة — لا يراها أي مستودع حتى تنشرها'
              : 'نُشر طلب التسعير — تظهر عروض الأسعار بعد انتهاء المهلة');
      Navigator.pop(context, true);
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
      appBar: const InnerTopBar(title: 'إنشاء طلب تسعير'),
      body: Form(
        key: _formKey,
        // SingleChildScrollView لا ListView: الأخيرة تُزيل الحقول الخارجة
        // عن الشاشة فيتخطّاها `validate()` ويُرجع true على نموذج ناقص.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حدّد الأصناف والكميات التي تحتاجها، وستصلك عروض أسعار من '
                'المستودعات التي تغطي منطقتك.',
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _title,
                label: 'عنوان الطلب',
                hint: 'طلب تسعير — أدوية القلب',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل عنواناً للطلب' : null,
              ),
              const SizedBox(height: 4),
              Text('يظهر للمستودعات في قائمة طلبات التسعير',
                  style: context.text.labelSmall?.copyWith(color: tk.hint)),

              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _description,
                label: 'وصف الطلب (اختياري)',
                hint: 'نحتاج كميات شهرية ثابتة، ويُفضَّل تسليم دفعة واحدة.',
              ),

              const SizedBox(height: AppSpacing.lg),
              Text('الأصناف المطلوبة', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.sm),

              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DraftItemCard(
                    item: item,
                    onRemove: () => setState(() => _items.remove(item)),
                    onQuantity: (v) {
                      if (v < 1) return;
                      setState(() => item.quantity = v);
                    },
                  ),
                ),

              // زرّ بحدّ متقطّع (Figma) — إضافةٌ لا إجراء رئيسي.
              _DashedAddButton(
                label: _items.isEmpty
                    ? 'إضافة صنف من الكتالوج'
                    : 'تعديل الأصناف (${_items.length})',
                onTap: _pickItems,
              ),

              const SizedBox(height: AppSpacing.lg),
              Text('آخر موعد لاستقبال عروض الأسعار',
                  style: context.text.labelMedium),
              const SizedBox(height: 6),
              AppCard(
                onTap: _pickDeadline,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, size: 18, color: tk.hint),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${_expiresAt.year}/${_expiresAt.month}/${_expiresAt.day}'
                        ' — ${_expiresAt.hour.toString().padLeft(2, '0')}:'
                        '${_expiresAt.minute.toString().padLeft(2, '0')}',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 16, color: tk.hint),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: tk.goldSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: tk.gold),
                ),
                child: Text(
                  'يصل طلبك تلقائياً إلى المستودعات التي تخدم منطقتك، وتبقى '
                  'عروض الأسعار مخفية عنك وعن المنافسين حتى انتهاء المهلة.',
                  style: context.text.bodySmall?.copyWith(color: tk.goldStrong),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.outline)),
            boxShadow: tk.navShadow,
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
          // ٣:٢ لا ٢:١ — «حفظ كمسودة» يحتاج عرضاً يسع سطراً واحداً، وبنسبة
          // الثلث كان ينكسر سطرين. النشر يبقى الأعرض لأنه الإجراء الرئيسي.
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'نشر طلب التسعير',
                  loading: _saving,
                  onPressed: _saving ? null : () => _submit(asDraft: false),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'حفظ كمسودة',
                  variant: AppButtonVariant.outline,
                  onPressed: _saving ? null : () => _submit(asDraft: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// بطاقة صنف في الطلب (Figma: الأصناف المطلوبة).
class _DraftItemCard extends StatefulWidget {
  const _DraftItemCard({
    required this.item,
    required this.onRemove,
    required this.onQuantity,
  });

  final _DraftItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantity;

  @override
  State<_DraftItemCard> createState() => _DraftItemCardState();
}

class _DraftItemCardState extends State<_DraftItemCard> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.item.quantity > 0 ? '${widget.item.quantity}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final m = widget.item.catalogItem;

    final spec = [
      if (m.genericName.isNotEmpty) m.genericName,
      m.dosageForm.label,
      if (m.strength > 0) '${m.strength.toStringAsFixed(0)} ملغ',
    ].join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (m.manufacturerName.isNotEmpty)
                      Text(m.manufacturerName,
                          style: context.text.labelSmall?.copyWith(color: tk.hint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'الكمية',
                    suffixText: 'عبوة',
                    suffixStyle: context.text.labelSmall?.copyWith(color: tk.hint),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                  ),
                  onChanged: (v) => widget.onQuantity(int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('حذف'),
            style: TextButton.styleFrom(foregroundColor: cs.error),
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.primary),
          color: cs.primary.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(label,
                style: context.text.bodyMedium?.copyWith(color: cs.primary)),
          ],
        ),
      ),
    );
  }
}

// ── اختيار الأصناف من الكتالوج (Figma: اختيار الأصناف) ───────────────
class _PickItemsSheet extends ConsumerStatefulWidget {
  const _PickItemsSheet({required this.already});
  final List<_DraftItem> already;

  @override
  ConsumerState<_PickItemsSheet> createState() => _PickItemsSheetState();
}

class _PickItemsSheetState extends ConsumerState<_PickItemsSheet> {
  List<MedicineCatalogItem> _results = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  /// معرّف صنف الكتالوج ← الكمية المطلوبة.
  late final Map<String, int> _selected = {
    for (final d in widget.already) d.catalogItem.id: d.quantity,
  };

  /// نحتفظ بالأصناف المختارة ولو خرجت من نتائج البحث الحالية، وإلا ضاع
  /// اختيار المستخدم بمجرّد تغيير كلمة البحث.
  late final Map<String, MedicineCatalogItem> _known = {
    for (final d in widget.already) d.catalogItem.id: d.catalogItem,
  };

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(medicineCatalogRepositoryProvider)
          .search(name: q.trim().isEmpty ? null : q.trim(), limit: 40);
      if (!mounted) return;
      for (final m in list) {
        _known[m.id] = m;
      }
      setState(() {
        _results = list;
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

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(v));
  }

  void _toggle(MedicineCatalogItem m, bool on) {
    setState(() {
      if (on) {
        _selected[m.id] = 0; // حقل فارغ — المستخدم يدخل الكمية
      } else {
        _selected.remove(m.id);
      }
    });
  }

  void _setQty(String id, int v) {
    if (v < 1) return;
    setState(() => _selected[id] = v);
  }

  void _confirm() {
    // التحقق أن كل صنف مختار لديه كمية > 0
    for (final entry in _selected.entries) {
      if (entry.value < 1) {
        AppSnackbar.error(context, 'أدخل كمية صحيحة لكل صنف محدد');
        return;
      }
    }
    final out = <_DraftItem>[];
    for (final entry in _selected.entries) {
      final m = _known[entry.key];
      if (m != null) out.add(_DraftItem(catalogItem: m, quantity: entry.value));
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('اختيار الأصناف', style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppSearchBar(
              hint: 'ابحث في كتالوج الأدوية…',
              autofocus: false,
              onChanged: _onQueryChanged,
              onScanTap: () async {
                // الماسح حقيقي: الرمز يُمرَّر إلى بحث الكتالوج نفسه.
                final code = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
                );
                if (code != null && code.isNotEmpty) _search(code);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'حدّد الأصناف التي تحتاجها وكمياتها — تظهر للمستودعات التي '
                'تغطي منطقتك',
                style: context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: _loading
                ? const AppListSkeleton(variant: SkeletonVariant.row)
                : _error != null
                    ? ErrorState(message: _error!, onRetry: () => _search(''))
                    : _results.isEmpty
                        ? const EmptyState(
                            icon: Icons.medication_outlined,
                            message: 'لا دواء يطابق بحثك في الكتالوج')
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) {
                              final m = _results[i];
                              final qty = _selected[m.id];
                              return _CatalogRow(
                                medicine: m,
                                quantity: qty,
                                onToggle: (on) => _toggle(m, on),
                                onQty: (v) => _setQty(m.id, v),
                              );
                            },
                          ),
          ),

          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.outline)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('المحدد',
                          style:
                              context.text.labelSmall?.copyWith(color: tk.hint)),
                      Text(
                        '${_selected.length} '
                        '${_selected.length == 1 ? 'صنف' : 'أصناف'}',
                        style: context.text.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'إضافة الأصناف إلى الطلب',
                      onPressed: _selected.isEmpty ? null : _confirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogRow extends StatefulWidget {
  const _CatalogRow({
    required this.medicine,
    required this.quantity,
    required this.onToggle,
    required this.onQty,
  });

  final MedicineCatalogItem medicine;
  final int? quantity;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQty;

  @override
  State<_CatalogRow> createState() => _CatalogRowState();
}

class _CatalogRowState extends State<_CatalogRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final q = widget.quantity;
    _ctrl = TextEditingController(text: (q != null && q > 0) ? '$q' : '');
  }

  @override
  void didUpdateWidget(_CatalogRow old) {
    super.didUpdateWidget(old);
    // عند إلغاء التحديد ثم إعادته، نفرّغ الحقل
    if (old.quantity != null && widget.quantity == null) {
      _ctrl.clear();
    }
    if (old.quantity == null && widget.quantity != null) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final selected = widget.quantity != null;

    return AppCard(
      onTap: () => widget.onToggle(!selected),
      color: selected ? tk.brandSurface : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.medicine.displayName,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [widget.medicine.genericName, widget.medicine.dosageForm.label]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: context.text.bodySmall?.copyWith(color: tk.hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: selected ? cs.primary : cs.outline, width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                    : null,
              ),
            ],
          ),
          // حقل الكمية يظهر عند التحديد فقط — فارغ كتلميح، يدخله المستخدم يدوياً.
          if (selected) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text('الكمية المطلوبة (عبوة)',
                      style: context.text.bodySmall?.copyWith(color: tk.hint)),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'أدخل الكمية',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                    onChanged: (v) => widget.onQty(int.tryParse(v) ?? 0),
                    onTap: () {
                      // منع نشر النقر للبطاقة عند التفاعل مع الحقل
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
