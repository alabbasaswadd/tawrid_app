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
import 'package:tawrid_app/features/ph_medicines/widgets/catalog_filter_widgets.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';
import 'package:tawrid_app/shared/utils/money.dart';

// كتالوج الأدوية الوطني عند الصيدلي (نشرة الأسعار) — مرجعٌ دوائي يجيب
// «ما هذا الدواء وكم سعره النظامي؟».
//
// كاتالوج المستودعات («من يبيعه الآن وبكم؟») صار شاشةً مستقلّة
// (PhWarehouseCatalogPage): سؤالان مختلفان لا يُدفَن أحدهما خلف مبدّل،
// ولكلٍّ مجموعةُ فلاترِه.
class PhMedicineSearchPage extends ConsumerStatefulWidget {
  const PhMedicineSearchPage({super.key});

  @override
  ConsumerState<PhMedicineSearchPage> createState() =>
      _PhMedicineSearchPageState();
}

class _PhMedicineSearchPageState extends ConsumerState<PhMedicineSearchPage> {
  static const int _catalogPageSize = 30;

  final _searchController = TextEditingController();
  final _catalogScroll = ScrollController();
  Timer? _debounce;

  final List<MedicineCatalogItem> _catalogResults = [];
  int _catalogOffset = 0;
  bool _catalogHasMore = true;
  bool _catalogLoadingMore = false;
  bool _catalogLoading = true;
  String? _catalogError;
  String? _catalogManufacturer;
  DosageForm? _catalogDosageForm;

  int get _activeFilterCount =>
      (_catalogManufacturer != null ? 1 : 0) +
      (_catalogDosageForm != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _catalogScroll.addListener(_onCatalogScroll);
    _runCatalogSearch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runCatalogSearch(reset: true),
    );
  }

  void _onCatalogScroll() {
    if (!_catalogHasMore || _catalogLoadingMore || _catalogLoading) return;
    if (_catalogScroll.position.pixels >=
        _catalogScroll.position.maxScrollExtent - 320) {
      _loadMoreCatalog();
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runCatalogSearch(reset: true);
  }

  Future<void> _openFilters() async {
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
        trailing: FiltersBtn(
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
              onSubmitted: (_) => _runCatalogSearch(reset: true),
              onScanTap: _scanBarcode,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // مدخل كاتالوج المستودعات — كان تاباً هنا، وصار شاشةً مستقلّة.
          // يبقى الرابط في موضعه القديم فلا يفقد من اعتاده طريقه إليه.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: AppButton(
              label: 'كاتالوج المستودعات — من يبيعه الآن وبكم؟',
              icon: Icons.storefront_outlined,
              variant: AppButtonVariant.tonal,
              onPressed: () => context.push(TRoutes.phWarehouseCatalog),
            ),
          ),

          if (_activeFilterCount > 0) ...[
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
          ],

          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildCatalogBody()),
        ],
      ),
    );
  }

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
          FilterChipCloseable(
            label: manufacturer!,
            onRemove: onClearManufacturer,
          ),
        if (dosageForm != null)
          FilterChipCloseable(
            label: dosageForm!.label,
            onRemove: onClearDosage,
          ),
      ],
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
                    FilterOptionRow(
                      icon: AppIcons.pill,
                      title: 'كل الأشكال',
                      selected: _pickedForm == null,
                      onTap: () => setState(() => _pickedForm = null),
                    ),
                    for (final f in DosageForm.values) ...[
                      const SizedBox(height: AppSpacing.xs),
                      FilterOptionRow(
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
                      FilterOptionRow(
                        icon: AppIcons.search,
                        title: 'كل الشركات',
                        selected: _pickedMfr == null,
                        onTap: () => setState(() => _pickedMfr = null),
                      ),
                      for (final name in _filtered) ...[
                        const SizedBox(height: AppSpacing.xs),
                        FilterOptionRow(
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

