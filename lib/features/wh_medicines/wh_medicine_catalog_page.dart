import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/warehouse_medicine_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';

// تصفّح/بحث مكتبة الأدوية المركزية (الكاتالوج العام) وإضافة ما يُريده
// المستودع إلى قائمته — بحث أونلاين حيّ + ترقيم صفحات (تمرير لانهائي) +
// مسح باركود بالكاميرا.
class WhMedicineCatalogPage extends ConsumerStatefulWidget {
  const WhMedicineCatalogPage({super.key});

  @override
  ConsumerState<WhMedicineCatalogPage> createState() => _WhMedicineCatalogPageState();
}

class _WhMedicineCatalogPageState extends ConsumerState<WhMedicineCatalogPage> {
  static const int _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<MedicineCatalogItem> _results = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  Set<String> _addedCatalogIds = {};
  final Set<String> _addingNow = {};
  bool _loading = true;
  String? _error;

  String? _manufacturer; // الشركة المختارة (null = كل الشركات)
  List<String>? _manufacturers; // قائمة الشركات (تُحمّل عند أول فتح للفلتر)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mine = await ref.read(warehouseMedicineRepositoryProvider).getMine();
      _addedCatalogIds = mine.map((m) => m.catalogItemId).toSet();
      await _runSearch(reset: true);
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(reset: true));
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _hasMore = true;
      });
    }
    try {
      final list = await ref.read(medicineCatalogRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            manufacturer: _manufacturer,
            limit: _pageSize,
            offset: reset ? 0 : _offset,
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _results
            ..clear()
            ..addAll(list);
        } else {
          _results.addAll(list);
        }
        _offset = _results.length;
        _hasMore = list.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    await _runSearch(reset: false);
  }

  Future<void> _pickManufacturer() async {
    if (_manufacturers == null) {
      try {
        _manufacturers = await ref.read(medicineCatalogRepositoryProvider).getManufacturers();
      } catch (e) {
        if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
        return;
      }
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ManufacturerPickerSheet(
        items: _manufacturers ?? const [],
        selected: _manufacturer,
      ),
    );
    if (picked == null) return; // أُغلقت بلا اختيار
    setState(() => _manufacturer = picked.isEmpty ? null : picked);
    _runSearch(reset: true);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runSearch(reset: true);
  }

  Future<void> _add(MedicineCatalogItem item) async {
    setState(() => _addingNow.add(item.id));
    try {
      await ref.read(warehouseMedicineRepositoryProvider).add(item.id);
      if (mounted) {
        setState(() {
          _addedCatalogIds.add(item.id);
          _addingNow.remove(item.id);
        });
        AppSnackbar.success(context, 'تمت إضافة ${item.displayName} إلى مستودعك');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingNow.remove(item.id));
        AppSnackbar.error(context, ApiException.from(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'الكتالوج العام'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
            // شريط البحث الموحّد (Figma: شريط بحث) — نفس الحقل في كل
            // الشاشات: عدسة في بداية القراءة وباركود في الطرف المقابل.
            child: AppSearchBar(
              controller: _searchController,
              hint: 'ابحث باسم الدواء أو المادة الفعالة…',
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _runSearch(reset: true),
              onScanTap: _scanBarcode,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickManufacturer,
                    icon: const Icon(Icons.factory_outlined, size: 18),
                    label: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _manufacturer ?? 'كل الشركات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _manufacturer != null
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                      side: BorderSide(
                        color: _manufacturer != null
                            ? context.colors.primary
                            : context.colors.outline,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                  ),
                ),
                if (_manufacturer != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'إزالة فلتر الشركة',
                    onPressed: () {
                      setState(() => _manufacturer = null);
                      _runSearch(reset: true);
                    },
                  ),
                ],
              ],
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${_results.length} دواءً معتمداً في كتالوج المنصّة',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.tokens.hint),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: () => _runSearch(reset: true));

    if (_results.isEmpty) {
      return const EmptyState(message: 'لا توجد نتائج', icon: Icons.search_off_outlined);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      // +1 للحاشية، و+1 أخرى لمؤشّر تحميل الصفحة التالية إن وُجد.
      itemCount: _results.length + 1 + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length && !_hasMore) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'الكتالوج عام تديره المنصّة. إضافة دواء تُبقيه صنفاً في مخزونك '
              'لتحدّد سعره وكمياته داخل كل عرض.',
              style: context.text.labelSmall
                  ?.copyWith(color: context.tokens.hint),
            ),
          );
        }
        if (index >= _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final item = _results[index];
        final added = _addedCatalogIds.contains(item.id);
        final adding = _addingNow.contains(item.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName,
                          style: context.text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (item.genericName.isNotEmpty) item.genericName,
                          item.dosageForm.label,
                          if (item.strength > 0)
                            '${item.strength.toStringAsFixed(0)} ملغ',
                        ].join(' · '),
                        style: context.text.bodySmall
                            ?.copyWith(color: context.tokens.hint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // ما هو في المخزون شارةٌ لا زرّ: لا إجراء عليه، وإظهار زرّ
                // مُعطَّل يوحي بإمكان إضافته مرّتين.
                if (added)
                  const StatusBadge(
                      label: 'في مخزونك',
                      tone: StatusTone.success,
                      icon: Icons.check)
                else if (adding)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  AppButton(
                    label: 'أضف لمخزونك',
                    icon: Icons.add,
                    fullWidth: false,
                    compact: true,
                    variant: AppButtonVariant.tonal,
                    onPressed: () => _add(item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ورقة اختيار الشركة — قائمة قابلة للبحث. تُرجِع اسم الشركة، أو سلسلة
// فارغة لـ "كل الشركات"، أو null عند الإغلاق بلا اختيار.
class _ManufacturerPickerSheet extends StatefulWidget {
  const _ManufacturerPickerSheet({required this.items, required this.selected});
  final List<String> items;
  final String? selected;

  @override
  State<_ManufacturerPickerSheet> createState() => _ManufacturerPickerSheetState();
}

class _ManufacturerPickerSheetState extends State<_ManufacturerPickerSheet> {
  final _filterController = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilter(String q) {
    final t = q.trim().toLowerCase();
    setState(() {
      _filtered = t.isEmpty
          ? widget.items
          : widget.items.where((m) => m.toLowerCase().contains(t)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('اختر الشركة', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _filterController,
                    onChanged: _onFilter,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن شركة...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear_all),
                    title: const Text('كل الشركات'),
                    trailing: widget.selected == null
                        ? Icon(Icons.check, color: context.colors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                  const Divider(height: 1),
                  for (final m in _filtered)
                    ListTile(
                      dense: true,
                      title: Text(m),
                      trailing: widget.selected == m
                          ? Icon(Icons.check, color: context.colors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
