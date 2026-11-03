import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';

// تعديل أصناف طلبية في حالة «بانتظار التأكيد» — الخادم يرفض التعديل بعد
// تأكيد المستودع، فهذه الشاشة تُفتح فقط عند status == pending.
class PhEditOrderPage extends ConsumerStatefulWidget {
  const PhEditOrderPage({required this.order, super.key});

  final SupplyOrderDetail order;

  @override
  ConsumerState<PhEditOrderPage> createState() => _PhEditOrderPageState();
}

class _PhEditOrderPageState extends ConsumerState<PhEditOrderPage> {
  late final List<_EditItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // ابدأ بالأصناف الحالية — يستطيع الصيدلي تعديل كمياتها أو حذفها أو إضافة جديدة.
    _items = widget.order.items
        .map((i) => _EditItem.fromOrderItem(i))
        .toList();
  }

  Future<void> _pickItems() async {
    final picked = await showModalBottomSheet<List<_EditItem>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CatalogPickerSheet(already: _items),
    );
    if (picked == null) return;
    setState(() {
      _items
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      AppSnackbar.error(context, 'أضف صنفاً واحداً على الأقل');
      return;
    }
    for (final item in _items) {
      if (item.quantity < 1) {
        AppSnackbar.error(context, 'تحقّق من كميات الأصناف — لا يُقبَل صفر');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(supplyOrderRepositoryProvider).updateOrderItems(
            widget.order.id,
            _items.map((e) => e.toOrderItem()).toList(),
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'حُدِّثت الطلبية بنجاح');
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
      appBar: InnerTopBar(
        title: 'تعديل الطلبية ${widget.order.orderNumber}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'يمكنك تعديل الأصناف والكميات ما دام المستودع لم يؤكّد الطلبية بعد.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.lg),

            Text('الأصناف', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),

            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _EditItemCard(
                  item: item,
                  onRemove: () => setState(() => _items.remove(item)),
                  onQuantity: (v) {
                    if (v < 1) return;
                    setState(() => item.quantity = v);
                  },
                ),
              ),

            _DashedAddButton(
              label: _items.isEmpty
                  ? 'إضافة صنف من الكتالوج'
                  : 'تعديل الأصناف (${_items.length})',
              onTap: _pickItems,
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
            label: 'حفظ التعديلات',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ),
      ),
    );
  }
}

// ── نموذج صنف للتعديل ────────────────────────────────────────────────────
class _EditItem {
  _EditItem({
    required this.medicineName,
    required this.catalogItemId,
    required this.quantity,
  });

  factory _EditItem.fromOrderItem(SupplyOrderItem i) => _EditItem(
        medicineName: i.medicineName,
        catalogItemId: i.catalogItemId,
        quantity: i.quantity.round(),
      );

  factory _EditItem.fromCatalog(MedicineCatalogItem m, int qty) => _EditItem(
        medicineName: m.displayName,
        catalogItemId: m.id,
        quantity: qty,
      );

  final String medicineName;
  final String? catalogItemId;
  int quantity;

  SupplyOrderItem toOrderItem() => SupplyOrderItem(
        id: '',
        medicineName: medicineName,
        catalogItemId: catalogItemId,
        quantity: quantity.toDouble(),
        unit: 'عبوة',
      );
}

// ── بطاقة صنف قابل للتعديل ─────────────────────────────────────────────
class _EditItemCard extends StatefulWidget {
  const _EditItemCard({
    required this.item,
    required this.onRemove,
    required this.onQuantity,
  });

  final _EditItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantity;

  @override
  State<_EditItemCard> createState() => _EditItemCardState();
}

class _EditItemCardState extends State<_EditItemCard> {
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(widget.item.medicineName,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
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
                  onChanged: (v) =>
                      widget.onQuantity(int.tryParse(v) ?? 0),
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

// ── زر إضافة بحدّ متقطّع ──────────────────────────────────────────────
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

// ── ورقة اختيار أصناف من الكتالوج ───────────────────────────────────────
class _CatalogPickerSheet extends ConsumerStatefulWidget {
  const _CatalogPickerSheet({required this.already});
  final List<_EditItem> already;

  @override
  ConsumerState<_CatalogPickerSheet> createState() =>
      _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends ConsumerState<_CatalogPickerSheet> {
  List<MedicineCatalogItem> _results = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  late final Map<String, int> _selected = {
    for (final d in widget.already)
      if (d.catalogItemId != null) d.catalogItemId!: d.quantity,
  };

  late final Map<String, MedicineCatalogItem> _known = {};

  // أصناف يدوية (بلا catalogItemId) تُحتفَظ بها دائماً.
  late final List<_EditItem> _manualItems =
      widget.already.where((i) => i.catalogItemId == null).toList();

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
    _debounce = Timer(
        const Duration(milliseconds: 450), () => _search(v));
  }

  void _toggle(MedicineCatalogItem m, bool on) {
    setState(() {
      if (on) {
        _selected[m.id] = 0;
      } else {
        _selected.remove(m.id);
      }
    });
  }

  void _confirm() {
    for (final entry in _selected.entries) {
      if (entry.value < 1) {
        AppSnackbar.error(context, 'أدخل كمية صحيحة لكل صنف محدد');
        return;
      }
    }
    final out = <_EditItem>[..._manualItems];
    for (final entry in _selected.entries) {
      final m = _known[entry.key];
      if (m != null) {
        out.add(_EditItem.fromCatalog(m, entry.value));
      }
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
              hint: 'ابحث في كتالوج الأدوية…',
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
          Expanded(
            child: _loading
                ? const AppListSkeleton(variant: SkeletonVariant.row)
                : _error != null
                    ? ErrorState(
                        message: _error!, onRetry: () => _search(''))
                    : _results.isEmpty
                        ? const EmptyState(
                            icon: Icons.medication_outlined,
                            message: 'لا دواء يطابق بحثك في الكتالوج')
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
                              final m = _results[i];
                              final qty = _selected[m.id];
                              return _CatalogRow(
                                medicine: m,
                                quantity: qty,
                                onToggle: (on) => _toggle(m, on),
                                onQty: (v) => setState(
                                    () => _selected[m.id] = v),
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
                      label: 'تطبيق التعديلات',
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
                    Text(widget.medicine.displayName,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        widget.medicine.genericName,
                        widget.medicine.dosageForm.label
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: context.text.bodySmall
                          ?.copyWith(color: tk.hint),
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
                  child: Text('الكمية (عبوة)',
                      style: context.text.bodySmall
                          ?.copyWith(color: tk.hint)),
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
                    onChanged: (v) =>
                        widget.onQty(int.tryParse(v) ?? 0),
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
