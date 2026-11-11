import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/medicine_search_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/repositories/warehouse_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';

class _DraftItem {
  _DraftItem({required this.result, required this.quantity});

  final MedicineSearchResult result;
  int quantity;

  String get key =>
      result.warehouseMedicineId ?? result.salesOfferItemId ?? result.catalogItemId ?? result.medicineName;

  SupplyOrderItem toOrderItem() => SupplyOrderItem(
        id: '',
        medicineName: result.medicineName,
        catalogItemId: result.catalogItemId,
        quantity: quantity.toDouble(),
        unit: result.unit,
      );
}

// إنشاء طلبية توريد مباشرة (الصيدلي).
// يختار الصيدلي المستودع ثم الأصناف من الكتالوج المركزي.
class PhCreateOrderPage extends ConsumerStatefulWidget {
  const PhCreateOrderPage({super.key});

  @override
  ConsumerState<PhCreateOrderPage> createState() => _PhCreateOrderPageState();
}

class _PhCreateOrderPageState extends ConsumerState<PhCreateOrderPage> {
  final _notesCtrl = TextEditingController();
  WarehousePicker? _warehouse;
  final List<_DraftItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickWarehouse() async {
    final picked = await showModalBottomSheet<WarehousePicker>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _WarehousePickerSheet(),
    );
    if (picked == null) return;
    setState(() => _warehouse = picked);
  }

  Future<void> _pickItems() async {
    if (_warehouse == null) {
      AppSnackbar.error(context, 'اختر مستودعاً أولاً قبل اختيار الأصناف');
      return;
    }
    final picked = await showModalBottomSheet<List<_DraftItem>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ItemPickerSheet(
        already: _items,
        warehouseId: _warehouse!.id,
      ),
    );
    if (picked == null) return;
    setState(() {
      _items
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _submit() async {
    if (_warehouse == null) {
      AppSnackbar.error(context, 'اختر مستودعاً أولاً');
      return;
    }
    if (_items.isEmpty) {
      AppSnackbar.error(context, 'أضف صنفاً واحداً على الأقل');
      return;
    }

    setState(() => _saving = true);
    try {
      final order = await ref.read(supplyOrderRepositoryProvider).createOrder(
            supplyWarehouseId: _warehouse!.id,
            items: _items.map((d) => d.toOrderItem()).toList(),
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      AppSnackbar.success(
          context, 'أُنشئت الطلبية ${order.orderNumber} — بانتظار التأكيد');
      context.go(TRoutes.phOrders);
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
      appBar: const InnerTopBar(title: 'طلبية جديدة'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر المستودع وحدّد الأصناف التي تحتاجها وكمياتها.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── اختيار المستودع ───────────────────────────────────────────
            Text('المستودع', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            _warehouse == null
                ? _DashedPickButton(
                    icon: AppIcons.warehouse,
                    label: 'اختر المستودع',
                    onTap: _pickWarehouse,
                  )
                : _SelectedWarehouseCard(
                    warehouse: _warehouse!,
                    onChangeTap: _pickWarehouse,
                  ),

            const SizedBox(height: AppSpacing.lg),

            // ── الأصناف ───────────────────────────────────────────────────
            Text('الأصناف المطلوبة', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),

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

            _DashedPickButton(
              icon: AppIcons.pill,
              label: _items.isEmpty
                  ? 'إضافة صنف من المستودع'
                  : 'تعديل الأصناف (${_items.length})',
              onTap: _warehouse == null ? null : _pickItems,
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── ملاحظات اختيارية ─────────────────────────────────────────
            AppTextField(
              controller: _notesCtrl,
              label: 'ملاحظات (اختياري)',
              hint: 'أي تعليمات خاصة بهذه الطلبية…',
            ),
          ],
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
          child: AppButton(
            label: 'إرسال الطلبية',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ),
      ),
    );
  }
}

// ── بطاقة المستودع المختار ──────────────────────────────────────────────
class _SelectedWarehouseCard extends StatelessWidget {
  const _SelectedWarehouseCard({
    required this.warehouse,
    required this.onChangeTap,
  });

  final WarehousePicker warehouse;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tk.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: AppIcon(AppIcons.warehouse, size: 20, color: cs.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warehouse.name, style: context.text.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${warehouse.city}، ${warehouse.governorate}',
                  style:
                      context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeTap,
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }
}

// ── زر اختيار بحدّ متقطّع ────────────────────────────────────────────────
class _DashedPickButton extends StatelessWidget {
  const _DashedPickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppIcons icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: disabled ? cs.outline : cs.primary),
          color: disabled
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : cs.primary.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 18,
                color: disabled ? context.tokens.hint : cs.primary),
            const SizedBox(width: 6),
            Text(label,
                style: context.text.bodyMedium?.copyWith(
                    color: disabled ? context.tokens.hint : cs.primary)),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة صنف مضاف ─────────────────────────────────────────────────────
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
        text: widget.item.quantity > 0 ? '${widget.item.quantity}' : '');
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
    final r = widget.item.result;

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
                    Text(r.medicineName,
                        style: context.text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (r.specLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(r.specLine,
                          style: context.text.bodySmall
                              ?.copyWith(color: tk.hint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
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
                    suffixText: r.unit,
                    suffixStyle:
                        context.text.labelSmall?.copyWith(color: tk.hint),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
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

// ── ورقة اختيار المستودع ────────────────────────────────────────────────
class _WarehousePickerSheet extends ConsumerStatefulWidget {
  const _WarehousePickerSheet();

  @override
  ConsumerState<_WarehousePickerSheet> createState() =>
      _WarehousePickerSheetState();
}

class _WarehousePickerSheetState
    extends ConsumerState<_WarehousePickerSheet> {
  List<WarehousePicker> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await ref.read(warehouseRepositoryProvider).getActiveWarehouses();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<WarehousePicker> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((w) =>
            w.name.toLowerCase().contains(q) ||
            w.code.toLowerCase().contains(q) ||
            w.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('اختيار المستودع', style: context.text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppSearchBar(
              hint: 'ابحث باسم المستودع أو المدينة',
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const AppListSkeleton(variant: SkeletonVariant.row)
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? UiEmpty(
                            appIcon: AppIcons.warehouse,
                            message: _query.isEmpty
                                ? 'لا مستودعات نشطة تخدم مدينتك'
                                : 'لا مستودع يطابق بحثك',
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) {
                              final w = _filtered[i];
                              return _WarehouseRow(
                                warehouse: w,
                                onTap: () => Navigator.pop(context, w),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({required this.warehouse, required this.onTap});

  final WarehousePicker warehouse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final w = warehouse;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tk.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: AppIcon(AppIcons.warehouse, size: 20, color: cs.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name,
                    style: context.text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${w.city}، ${w.governorate}',
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (!w.servesAllAreas)
            const StatusBadge(label: 'يخدم مدينتك', tone: StatusTone.success)
          else
            const StatusBadge(label: 'يخدم الجميع', tone: StatusTone.neutral),
        ],
      ),
    );
  }
}

// ── ورقة اختيار الأصناف من مستودع محدّد ────────────────────────────────
class _ItemPickerSheet extends ConsumerStatefulWidget {
  const _ItemPickerSheet({required this.already, required this.warehouseId});
  final List<_DraftItem> already;
  final String warehouseId;

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  List<MedicineSearchResult> _results = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  late final Map<String, int> _selected = {
    for (final d in widget.already) d.key: d.quantity,
  };

  late final Map<String, MedicineSearchResult> _known = {
    for (final d in widget.already) d.key: d.result,
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
      final page = await ref
          .read(medicineSearchRepositoryProvider)
          .search(
            warehouseId: widget.warehouseId,
            name: q.trim().isEmpty ? null : q.trim(),
            limit: 40,
          );
      if (!mounted) return;
      for (final r in page.items) {
        final k = r.warehouseMedicineId ?? r.salesOfferItemId ?? r.catalogItemId ?? r.medicineName;
        _known[k] = r;
      }
      setState(() {
        _results = page.items;
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

  String _key(MedicineSearchResult r) =>
      r.warehouseMedicineId ?? r.salesOfferItemId ?? r.catalogItemId ?? r.medicineName;

  void _toggle(MedicineSearchResult r, bool on) {
    final k = _key(r);
    setState(() {
      if (on) {
        _selected[k] = 0;
      } else {
        _selected.remove(k);
      }
    });
  }

  void _setQty(String key, int v) {
    if (v < 1) return;
    setState(() => _selected[key] = v);
  }

  void _confirm() {
    for (final entry in _selected.entries) {
      if (entry.value < 1) {
        AppSnackbar.error(context, 'أدخل كمية صحيحة لكل صنف محدد');
        return;
      }
    }
    final out = <_DraftItem>[];
    for (final entry in _selected.entries) {
      final r = _known[entry.key];
      if (r != null) out.add(_DraftItem(result: r, quantity: entry.value));
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
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: AppSearchBar(
              hint: 'ابحث في أدوية هذا المستودع…',
              autofocus: false,
              onChanged: _onQueryChanged,
              onScanTap: () async {
                final code = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                      builder: (_) => const BarcodeScannerPage()),
                );
                if (code != null && code.isNotEmpty) _search(code);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'حدّد الأصناف التي تحتاجها وكمياتها',
                style:
                    context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const AppListSkeleton(variant: SkeletonVariant.row)
                : _error != null
                    ? ErrorState(
                        message: _error!, onRetry: () => _search(''))
                    : _results.isEmpty
                        ? const EmptyState(
                            icon: Icons.medication_outlined,
                            message: 'لا دواء متاح في هذا المستودع يطابق بحثك')
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) {
                              final r = _results[i];
                              final k = _key(r);
                              final qty = _selected[k];
                              return _CatalogRow(
                                medicine: r,
                                quantity: qty,
                                onToggle: (on) => _toggle(r, on),
                                onQty: (v) => _setQty(k, v),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                    top: BorderSide(color: context.colors.outline)),
              ),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('المحدد',
                          style: context.text.labelSmall
                              ?.copyWith(color: tk.hint)),
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
                      label: 'إضافة الأصناف إلى الطلبية',
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

  final MedicineSearchResult medicine;
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
    if (old.quantity != null && widget.quantity == null) _ctrl.clear();
    if (old.quantity == null && widget.quantity != null) _ctrl.clear();
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
                    Text(widget.medicine.medicineName,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if (widget.medicine.specLine.isNotEmpty)
                      Text(
                        widget.medicine.specLine,
                        style:
                            context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.medicine.netUnitPrice != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${widget.medicine.netUnitPrice!.toStringAsFixed(0)} ${widget.medicine.currency}',
                        style: context.priceBrandStyle,
                      ),
                    ],
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
                      color: selected ? cs.primary : cs.outline,
                      width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                    : null,
              ),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text('الكمية المطلوبة (${widget.medicine.unit})',
                      style:
                          context.text.bodySmall?.copyWith(color: tk.hint)),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                    onChanged: (v) => widget.onQty(int.tryParse(v) ?? 0),
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
