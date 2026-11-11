import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/medicine_search_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';
import 'package:tawrid_app/shared/utils/money.dart';

// كتالوج الأدوية الوطني عند الصيدلي (نشرة الأسعار) + كاتالوج المستودعات.
// تاب 1: الكاتالوج الوطني — مرجع لـ «ما هذا الدواء وكم سعره؟»
// تاب 2: كاتالوج المستودعات — «ما الأدوية التي تعرضها المستودعات الآن؟»
class PhMedicineSearchPage extends ConsumerStatefulWidget {
  const PhMedicineSearchPage({super.key});

  @override
  ConsumerState<PhMedicineSearchPage> createState() =>
      _PhMedicineSearchPageState();
}

class _PhMedicineSearchPageState extends ConsumerState<PhMedicineSearchPage> {
  static const int _catalogPageSize = 30;
  static const int _whPageSize = 30;

  int _tabIndex = 0;

  final _searchController = TextEditingController();
  final _catalogScroll = ScrollController();
  final _whScroll = ScrollController();
  Timer? _debounce;

  // ─── تاب 1: الكاتالوج الوطني ─────────────────────────────────────────
  final List<MedicineCatalogItem> _catalogResults = [];
  int _catalogOffset = 0;
  bool _catalogHasMore = true;
  bool _catalogLoadingMore = false;
  bool _catalogLoading = true;
  String? _catalogError;
  String? _catalogManufacturer;
  DosageForm? _catalogDosageForm;

  // ─── تاب 2: كاتالوج المستودعات ───────────────────────────────────────
  final List<MedicineSearchResult> _whResults = [];
  final Set<String> _whSeenIds = {};
  int _whRawOffset = 0;
  bool _whHasMore = true;
  bool _whLoadingMore = false;
  bool _whLoading = false;
  bool _whInitialized = false;
  String? _whError;
  String _whManufacturer = '';
  MedicineSearchSource _whSource = MedicineSearchSource.all;
  MedicineSearchSort _whSort = MedicineSearchSort.byDefault;

  int get _activeFilterCount {
    if (_tabIndex == 0) {
      return (_catalogManufacturer != null ? 1 : 0) +
          (_catalogDosageForm != null ? 1 : 0);
    } else {
      return (_whSource != MedicineSearchSource.all ? 1 : 0) +
          (_whSort != MedicineSearchSort.byDefault ? 1 : 0) +
          (_whManufacturer.isNotEmpty ? 1 : 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _catalogScroll.addListener(_onCatalogScroll);
    _whScroll.addListener(_onWhScroll);
    _runCatalogSearch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _catalogScroll.dispose();
    _whScroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runCatalogSearch(reset: true);
      if (_whInitialized) _runWhSearch(reset: true);
    });
  }

  void _onCatalogScroll() {
    if (!_catalogHasMore || _catalogLoadingMore || _catalogLoading) return;
    if (_catalogScroll.position.pixels >=
        _catalogScroll.position.maxScrollExtent - 320) {
      _loadMoreCatalog();
    }
  }

  void _onWhScroll() {
    if (!_whHasMore || _whLoadingMore || _whLoading) return;
    if (_whScroll.position.pixels >=
        _whScroll.position.maxScrollExtent - 320) {
      _loadMoreWh();
    }
  }

  Future<void> _runCatalogSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (reset) {
      setState(() {
        _catalogLoading = true;
        _catalogError = null;
        _catalogOffset = 0;
        _catalogHasMore = true;
      });
    }
    try {
      var list = await ref.read(medicineCatalogRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            manufacturer: _catalogManufacturer,
            limit: _catalogPageSize,
            offset: reset ? 0 : _catalogOffset,
          );
      if (_catalogDosageForm != null) {
        list = list.where((m) => m.dosageForm == _catalogDosageForm).toList();
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          _catalogResults
            ..clear()
            ..addAll(list);
        } else {
          _catalogResults.addAll(list);
        }
        _catalogOffset = _catalogResults.length;
        _catalogHasMore = list.length == _catalogPageSize;
        _catalogLoading = false;
        _catalogLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogError = ApiException.from(e).message;
        _catalogLoading = false;
        _catalogLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreCatalog() async {
    setState(() => _catalogLoadingMore = true);
    await _runCatalogSearch(reset: false);
  }

  Future<void> _runWhSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (!_whInitialized) setState(() => _whInitialized = true);
    if (reset) {
      setState(() {
        _whLoading = true;
        _whError = null;
        _whRawOffset = 0;
        _whHasMore = true;
        _whResults.clear();
        _whSeenIds.clear();
      });
    } else {
      setState(() => _whLoadingMore = true);
    }
    try {
      final page = await ref.read(medicineSearchRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            manufacturer: _whManufacturer.isEmpty ? null : _whManufacturer,
            source: _whSource,
            sort: _whSort,
            limit: _whPageSize,
            offset: reset ? 0 : _whRawOffset,
          );
      if (!mounted) return;
      final unique = <MedicineSearchResult>[];
      for (final r in page.items) {
        final key = r.catalogItemId ?? '${r.medicineName}_${r.warehouseName}';
        if (!_whSeenIds.contains(key)) {
          _whSeenIds.add(key);
          unique.add(r);
        }
      }
      setState(() {
        _whRawOffset += page.items.length;
        _whResults.addAll(unique);
        _whHasMore = page.items.length == _whPageSize;
        _whLoading = false;
        _whLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _whError = ApiException.from(e).message;
        _whLoading = false;
        _whLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreWh() async {
    await _runWhSearch(reset: false);
  }

  void _onTabChanged(int index) {
    setState(() => _tabIndex = index);
    if (index == 1 && !_whInitialized) {
      _runWhSearch(reset: true);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runCatalogSearch(reset: true);
    if (_whInitialized) _runWhSearch(reset: true);
  }

  Future<void> _openFilters() async {
    if (_tabIndex == 0) {
      await _openCatalogFilters();
    } else {
      await _openWhFilters();
    }
  }

  Future<void> _openCatalogFilters() async {
    final result = await showModalBottomSheet<
        ({String? manufacturer, DosageForm? dosageForm})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogFilterSheet(
        manufacturer: _catalogManufacturer,
        dosageForm: _catalogDosageForm,
      ),
    );
    if (result == null || !mounted) return;
    if (result.manufacturer == _catalogManufacturer &&
        result.dosageForm == _catalogDosageForm) {
      return;
    }
    setState(() {
      _catalogManufacturer = result.manufacturer;
      _catalogDosageForm = result.dosageForm;
    });
    _runCatalogSearch(reset: true);
  }

  Future<void> _openWhFilters() async {
    final result = await showModalBottomSheet<_WhFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhFilterSheet(
        source: _whSource,
        sort: _whSort,
        manufacturer: _whManufacturer,
      ),
    );
    if (result == null || !mounted) return;
    if (result.source == _whSource &&
        result.sort == _whSort &&
        result.manufacturer == _whManufacturer) {
      return;
    }
    setState(() {
      _whSource = result.source;
      _whSort = result.sort;
      _whManufacturer = result.manufacturer;
    });
    _runWhSearch(reset: true);
  }

  void _showDetails(MedicineCatalogItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MedicineDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'كتالوج الأدوية',
        trailing: _FiltersBtn(
          count: _activeFilterCount,
          onTap: _openFilters,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              0,
            ),
            child: AppSearchBar(
              controller: _searchController,
              hint: 'ابحث بالاسم أو الباركود…',
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _runCatalogSearch(reset: true);
                if (_whInitialized) _runWhSearch(reset: true);
              },
              onScanTap: _scanBarcode,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: AppSegmentedToggle(
              items: const [
                SegmentItem(label: 'الكاتالوج الوطني'),
                SegmentItem(label: 'كاتالوج المستودعات'),
              ],
              selected: _tabIndex,
              onChanged: _onTabChanged,
            ),
          ),

          if (_tabIndex == 0 && _activeFilterCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: _ActiveFiltersRow(
                manufacturer: _catalogManufacturer,
                dosageForm: _catalogDosageForm,
                onClearManufacturer: () {
                  setState(() => _catalogManufacturer = null);
                  _runCatalogSearch(reset: true);
                },
                onClearDosage: () {
                  setState(() => _catalogDosageForm = null);
                  _runCatalogSearch(reset: true);
                },
              ),
            ),
          ] else if (_tabIndex == 1 && _whManufacturer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _FilterChipCloseable(
                  label: _whManufacturer,
                  onRemove: () {
                    setState(() => _whManufacturer = '');
                    _runWhSearch(reset: true);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _tabIndex == 0
                ? _buildCatalogBody()
                : _buildWhBody(),
          ),
        ],
      ),
    );
  }

  // ── تاب 1: الكاتالوج الوطني ──────────────────────────────────────────
  Widget _buildCatalogBody() {
    if (_catalogLoading) {
      return const AppListSkeleton(variant: SkeletonVariant.row);
    }
    if (_catalogError != null) {
      return ErrorState(
        message: _catalogError!,
        onRetry: () => _runCatalogSearch(reset: true),
      );
    }
    if (_catalogResults.isEmpty) {
      return UiEmpty(
        message: 'لا نتائج',
        description: _activeFilterCount > 0
            ? 'لا دواء يطابق بحثك مع الفلاتر الحالية — جرّب توسيعها.'
            : 'ابحث باسم الدواء أو الباركود.',
        actionLabel: _activeFilterCount > 0 ? 'مسح الفلاتر' : null,
        onAction: _activeFilterCount > 0
            ? () {
                setState(() {
                  _catalogManufacturer = null;
                  _catalogDosageForm = null;
                });
                _runCatalogSearch(reset: true);
              }
            : null,
      );
    }

    return ListView.builder(
      controller: _catalogScroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      itemCount: _catalogResults.length + (_catalogLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _catalogResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = _catalogResults[index];
        return MedicineListTile(
          displayName: item.displayName,
          genericName: item.genericName,
          manufacturerName: item.manufacturerName,
          dosageForm: item.dosageForm,
          strength: item.strength,
          onTap: () => _showDetails(item),
          trailing: AppIcon(
            AppIcons.chevronForwardRtl,
            size: 16,
            color: context.colors.primary,
          ),
        );
      },
    );
  }

  // ── تاب 2: كاتالوج المستودعات ─────────────────────────────────────────
  Widget _buildWhBody() {
    if (_whLoading) {
      return const AppListSkeleton(variant: SkeletonVariant.row);
    }
    if (_whError != null) {
      return ErrorState(
        message: _whError!,
        onRetry: () => _runWhSearch(reset: true),
      );
    }
    if (!_whInitialized) {
      return const SizedBox.shrink();
    }
    if (_whResults.isEmpty) {
      return UiEmpty(
        message: 'لا أدوية متاحة',
        description: 'لا مستودع في منطقتك سعّر هذا الدواء بعد — '
            'جرّب بحثاً مختلفاً أو مسح الفلاتر.',
        actionLabel: _activeFilterCount > 0 ? 'مسح الفلاتر' : null,
        onAction: _activeFilterCount > 0
            ? () {
                setState(() {
                  _whSource = MedicineSearchSource.all;
                  _whSort = MedicineSearchSort.byDefault;
                  _whManufacturer = '';
                });
                _runWhSearch(reset: true);
              }
            : null,
      );
    }

    return ListView.builder(
      controller: _whScroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      itemCount: _whResults.length + (_whLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _whResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final r = _whResults[index];
        return MedicineListTile(
          displayName: r.medicineName,
          genericName: r.genericName,
          manufacturerName: r.manufacturerName,
          dosageForm: r.dosageForm ?? DosageForm.tablet,
          strength: r.strength,
          onTap: r.catalogItemId == null
              ? null
              : () => context.push(TRoutes.phMedicineInWarehouses(
                    catalogItemId: r.catalogItemId!,
                    name: r.medicineName,
                  )),
          trailing: AppIcon(
            AppIcons.chevronForwardRtl,
            size: 16,
            color: context.colors.primary,
          ),
        );
      },
    );
  }
}

// ── زر الفلاتر الدائري ────────────────────────────────────────────────────
class _FiltersBtn extends StatelessWidget {
  const _FiltersBtn({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: cs.surface,
          shape: CircleBorder(side: BorderSide(color: cs.outline)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AppIcon(AppIcons.sliders, size: 18, color: cs.onSurface),
              ),
            ),
          ),
        ),
        if (count > 0)
          PositionedDirectional(
            end: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: tk.brandDeep,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: context.text.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    height: 1,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── شريط الفلاتر النشطة ──────────────────────────────────────────────────
class _ActiveFiltersRow extends StatelessWidget {
  const _ActiveFiltersRow({
    required this.manufacturer,
    required this.dosageForm,
    required this.onClearManufacturer,
    required this.onClearDosage,
  });

  final String? manufacturer;
  final DosageForm? dosageForm;
  final VoidCallback onClearManufacturer;
  final VoidCallback onClearDosage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        if (manufacturer != null)
          _FilterChipCloseable(
            label: manufacturer!,
            onRemove: onClearManufacturer,
          ),
        if (dosageForm != null)
          _FilterChipCloseable(
            label: dosageForm!.label,
            onRemove: onClearDosage,
          ),
      ],
    );
  }
}

class _FilterChipCloseable extends StatelessWidget {
  const _FilterChipCloseable({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm,
        end: AppSpacing.xs,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: tk.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: AppIcon(AppIcons.x, size: 12, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

// ── سطر خيار موحّد في ورقة الفلاتر ──────────────────────────────────────
class _FilterOptionRow extends StatelessWidget {
  const _FilterOptionRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final AppIcons icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Material(
      color: selected ? tk.brandSurfaceSubtle : cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : tk.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AppIcon(
                    icon,
                    size: 16,
                    color: selected ? cs.onPrimary : cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                AppIcon(AppIcons.check, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── ورقة فلاتر الكاتالوج الوطني ──────────────────────────────────────────
class _CatalogFilterSheet extends ConsumerStatefulWidget {
  const _CatalogFilterSheet({
    required this.manufacturer,
    required this.dosageForm,
  });

  final String? manufacturer;
  final DosageForm? dosageForm;

  @override
  ConsumerState<_CatalogFilterSheet> createState() =>
      _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends ConsumerState<_CatalogFilterSheet> {
  List<String> _manufacturers = [];
  bool _loadingMfr = true;
  late String? _pickedMfr = widget.manufacturer;
  late DosageForm? _pickedForm = widget.dosageForm;
  final _mfrSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
  }

  @override
  void dispose() {
    _mfrSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManufacturers() async {
    try {
      final list =
          await ref.read(medicineCatalogRepositoryProvider).getManufacturers();
      if (!mounted) return;
      setState(() {
        _manufacturers = list;
        _loadingMfr = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMfr = false);
    }
  }

  List<String> get _filtered {
    final q = _mfrSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _manufacturers;
    return _manufacturers.where((m) => m.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Text('فلاتر الكتالوج', style: context.text.headlineSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _pickedMfr = null;
                      _pickedForm = null;
                      _mfrSearchCtrl.clear();
                    }),
                    child: const Text('مسح الكل'),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('الشكل الدوائي', style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    _FilterOptionRow(
                      icon: AppIcons.pill,
                      title: 'كل الأشكال',
                      selected: _pickedForm == null,
                      onTap: () => setState(() => _pickedForm = null),
                    ),
                    for (final f in DosageForm.values) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _FilterOptionRow(
                        icon: AppIcons.pill,
                        title: f.label,
                        selected: _pickedForm == f,
                        onTap: () => setState(
                          () => _pickedForm = _pickedForm == f ? null : f,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    Text('الشركة المصنّعة', style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    if (_loadingMfr)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else ...[
                      AppTextField(
                        controller: _mfrSearchCtrl,
                        hint: 'ابحث في الشركات…',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FilterOptionRow(
                        icon: AppIcons.search,
                        title: 'كل الشركات',
                        selected: _pickedMfr == null,
                        onTap: () => setState(() => _pickedMfr = null),
                      ),
                      for (final name in _filtered) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _FilterOptionRow(
                          icon: AppIcons.package,
                          title: name,
                          selected: _pickedMfr == name,
                          onTap: () => setState(
                            () => _pickedMfr = _pickedMfr == name ? null : name,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: 'تطبيق',
                onPressed: () => Navigator.pop(
                  context,
                  (manufacturer: _pickedMfr, dosageForm: _pickedForm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── نتيجة ورقة فلاتر كاتالوج المستودعات ─────────────────────────────────
class _WhFilters {
  const _WhFilters({
    required this.source,
    required this.sort,
    required this.manufacturer,
  });
  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;
}

// ── ورقة فلاتر كاتالوج المستودعات ────────────────────────────────────────
class _WhFilterSheet extends ConsumerStatefulWidget {
  const _WhFilterSheet({
    required this.source,
    required this.sort,
    required this.manufacturer,
  });
  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;

  @override
  ConsumerState<_WhFilterSheet> createState() => _WhFilterSheetState();
}

class _WhFilterSheetState extends ConsumerState<_WhFilterSheet> {
  late MedicineSearchSource _source = widget.source;
  late MedicineSearchSort _sort = widget.sort;
  late String? _pickedMfr =
      widget.manufacturer.isEmpty ? null : widget.manufacturer;
  final _mfrSearchCtrl = TextEditingController();
  List<String> _manufacturers = [];
  bool _loadingMfr = true;

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
  }

  @override
  void dispose() {
    _mfrSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManufacturers() async {
    try {
      final list =
          await ref.read(medicineCatalogRepositoryProvider).getManufacturers();
      if (!mounted) return;
      setState(() {
        _manufacturers = list;
        _loadingMfr = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMfr = false);
    }
  }

  List<String> get _filtered {
    final q = _mfrSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _manufacturers;
    return _manufacturers.where((m) => m.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Text('فلاتر المستودعات', style: context.text.headlineSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _source = MedicineSearchSource.all;
                      _sort = MedicineSearchSort.byDefault;
                      _pickedMfr = null;
                      _mfrSearchCtrl.clear();
                    }),
                    child: const Text('مسح الكل'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('الترتيب', style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    for (final s in MedicineSearchSort.values) ...[
                      _FilterOptionRow(
                        icon: AppIcons.sliders,
                        title: s.label,
                        selected: _sort == s,
                        onTap: () => setState(() => _sort = s),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    Text('المصدر', style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    for (final s in MedicineSearchSource.values) ...[
                      _FilterOptionRow(
                        icon: AppIcons.tag,
                        title: s.label,
                        selected: _source == s,
                        onTap: () => setState(() => _source = s),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    Text('الشركة المصنّعة', style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    if (_loadingMfr)
                      const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      if (_manufacturers.length > 4) ...[
                        AppTextField(
                          controller: _mfrSearchCtrl,
                          hint: 'ابحث في الشركات…',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _FilterOptionRow(
                        icon: AppIcons.search,
                        title: 'كل الشركات',
                        selected: _pickedMfr == null,
                        onTap: () => setState(() => _pickedMfr = null),
                      ),
                      for (final name in _filtered) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _FilterOptionRow(
                          icon: AppIcons.package,
                          title: name,
                          selected: _pickedMfr == name,
                          onTap: () => setState(
                            () => _pickedMfr = _pickedMfr == name ? null : name,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              child: AppButton(
                label: 'تطبيق',
                onPressed: () => Navigator.pop(
                  context,
                  _WhFilters(
                    source: _source,
                    sort: _sort,
                    manufacturer: _pickedMfr ?? '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ورقة تفاصيل الدواء ───────────────────────────────────────────────────
class _MedicineDetailSheet extends StatelessWidget {
  const _MedicineDetailSheet({required this.item});
  final MedicineCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(item.displayName, style: context.text.titleLarge),
            if (item.foreignName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.foreignName,
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _row(context, 'الاسم العلمي', item.genericName),
            _row(context, 'الشركة المصنّعة', item.manufacturerName),
            _row(
              context,
              'الشكل الدوائي',
              item.strength > 0
                  ? '${item.dosageForm.label} ${item.strength}'
                  : item.dosageForm.label,
            ),
            if (item.barcode.isNotEmpty)
              _row(context, 'الباركود', item.barcode),
            if (item.sakoCode.isNotEmpty)
              _row(context, 'رمز ساكو', item.sakoCode),
            const SizedBox(height: AppSpacing.md),
            Divider(color: cs.outline),
            const SizedBox(height: AppSpacing.sm),
            _priceRow(
                context, 'سعر الصيدلي', item.pricePharmacist, item.currency),
            _priceRow(
                context, 'سعر الجمهور', item.pricePublic, item.currency),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'ابحث عنه في المستودعات',
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(TRoutes.phMedicineInWarehouses(
                  catalogItemId: item.id,
                  name: item.displayName,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.tokens.hint),
            ),
          ),
          Expanded(child: Text(value, style: context.text.bodyMedium)),
        ],
      ),
    );
  }

  Widget _priceRow(
    BuildContext context,
    String label,
    double value,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.tokens.hint),
            ),
          ),
          Text(
            formatMoneyWith(value, currency),
            style: context.priceStyle,
          ),
        ],
      ),
    );
  }
}
