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
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/medicine_list_tile.dart';
import 'package:tawrid_app/shared/utils/money.dart';

// كتالوج الأدوية الوطني عند الصيدلي (نشرة الأسعار): بحث أونلاين حيّ +
// ترقيم صفحات + مسح باركود + فلترة بالشكل الدوائي والشركة المصنّعة.
//
// شاشة مرجعية لا شرائية: «ما هذا الدواء وكم سعره في النشرة؟». السؤال
// الآخر — «من يبيعه وبكم؟» — تجيبه شاشة بحث الأسعار، والعروض تبويبها.
class PhMedicineSearchPage extends ConsumerStatefulWidget {
  const PhMedicineSearchPage({super.key});

  @override
  ConsumerState<PhMedicineSearchPage> createState() =>
      _PhMedicineSearchPageState();
}

class _PhMedicineSearchPageState extends ConsumerState<PhMedicineSearchPage> {
  static const int _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<MedicineCatalogItem> _results = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
  String? _error;

  // ─── فلاتر ───────────────────────────────────────────────────────────────
  String? _manufacturer;
  DosageForm? _dosageForm;

  int get _activeFilterCount =>
      (_manufacturer != null ? 1 : 0) + (_dosageForm != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _runSearch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(reset: true),
    );
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
      var list = await ref.read(medicineCatalogRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            manufacturer: _manufacturer,
            limit: _pageSize,
            offset: reset ? 0 : _offset,
          );

      // الشكل الدوائي يُفلتَر محلياً لأن الخادم لا يدعمه بعد.
      if (_dosageForm != null) {
        list = list.where((m) => m.dosageForm == _dosageForm).toList();
      }

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

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runSearch(reset: true);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<
        ({String? manufacturer, DosageForm? dosageForm})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CatalogFilterSheet(
        manufacturer: _manufacturer,
        dosageForm: _dosageForm,
      ),
    );
    if (result == null || !mounted) return;
    if (result.manufacturer == _manufacturer &&
        result.dosageForm == _dosageForm) {
      return;
    }
    setState(() {
      _manufacturer = result.manufacturer;
      _dosageForm = result.dosageForm;
    });
    _runSearch(reset: true);
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
              onSubmitted: (_) => _runSearch(reset: true),
              onScanTap: _scanBarcode,
            ),
          ),

          // شريط الفلاتر النشطة
          if (_activeFilterCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: _ActiveFiltersRow(
                manufacturer: _manufacturer,
                dosageForm: _dosageForm,
                onClearManufacturer: () {
                  setState(() => _manufacturer = null);
                  _runSearch(reset: true);
                },
                onClearDosage: () {
                  setState(() => _dosageForm = null);
                  _runSearch(reset: true);
                },
              ),
            ),

          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () => _runSearch(reset: true),
      );
    }
    if (_results.isEmpty) {
      return UiEmpty(
        message: 'لا نتائج',
        description: _activeFilterCount > 0
            ? 'لا دواء يطابق بحثك مع الفلاتر الحالية — جرّب توسيعها.'
            : 'ابحث باسم الدواء أو الباركود.',
        actionLabel: _activeFilterCount > 0 ? 'مسح الفلاتر' : null,
        onAction: _activeFilterCount > 0
            ? () {
                setState(() {
                  _manufacturer = null;
                  _dosageForm = null;
                });
                _runSearch(reset: true);
              }
            : null,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      itemCount: _results.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
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
        final item = _results[index];
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

// ── زر الفلاتر الدائري بشارة العدد ──────────────────────────────────────────
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

// ── شريط الفلاتر النشطة (chips قابلة للإغلاق) ───────────────────────────────
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

// ── ورقة فلاتر الكتالوج ──────────────────────────────────────────────────────
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
    final tk = context.tokens;

    return SafeArea(
      top: false,
      child: Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.page,
            right: AppSpacing.page,
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // handle
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

            // عنوان + مسح
            Row(
              children: [
                Text('فلاتر الكتالوج', style: context.text.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _pickedMfr = null;
                    _pickedForm = null;
                    _mfrSearchCtrl.clear();
                  }),
                  child: Text(
                    'مسح الكل',
                    style: context.text.bodySmall?.copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // الشكل الدوائي
            Text('الشكل الدوائي', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppFilterChip(
                  label: 'الكل',
                  selected: _pickedForm == null,
                  onTap: () => setState(() => _pickedForm = null),
                ),
                for (final f in DosageForm.values)
                  AppFilterChip(
                    label: f.label,
                    selected: _pickedForm == f,
                    onTap: () =>
                        setState(() => _pickedForm = _pickedForm == f ? null : f),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // الشركة المصنّعة
            Text('الشركة المصنّعة', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (_loadingMfr)
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tk.brandDeep,
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final name = _filtered[i];
                    final picked = _pickedMfr == name;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      title: Text(name, style: context.text.bodyMedium),
                      trailing: picked
                          ? AppIcon(AppIcons.check, size: 16, color: cs.primary)
                          : null,
                      onTap: () =>
                          setState(() => _pickedMfr = picked ? null : name),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: 'تطبيق',
              onPressed: () => Navigator.pop(
                context,
                (manufacturer: _pickedMfr, dosageForm: _pickedForm),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ── ورقة تفاصيل الدواء ───────────────────────────────────────────────────────
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
            // الكتالوج يجيب «ما هذا الدواء وكم سعره في النشرة». هذا الزرّ
            // يصل بالسؤال التالي: «من يبيعه الآن وبكم؟» — ومعه البدائل
            // التي تحمل تركيبه العلمي نفسه، لتبقى أمامه خيارات حين لا
            // يعرضه مستودعٌ يخدم مدينته.
            AppButton(
              label: 'ابحث عنه في المستودعات',
              onPressed: () {
                // المُوجِّه يُلتقط قبل الإغلاق: سياق الورقة يُبطَل بالإغلاق
                // فلا يصلح للدفع بعده.
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
