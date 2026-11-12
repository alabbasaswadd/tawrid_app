import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/features/ph_medicines/widgets/catalog_filter_widgets.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/medicine_search_repository.dart';
import 'package:tawrid_app/repositories/warehouse_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/quantity_dialog.dart';

// كاتالوج المستودعات — «ما الأدوية التي تعرضها المستودعات الآن؟»
//
// كان تاباً ثانياً داخل الكتالوج الوطني، والشاشتان تجيبان سؤالين
// مختلفين: الوطني مرجعٌ دوائي (ما هذا الدواء وكم سعره النظامي؟) وهذا
// سوقٌ حيّ (من يبيعه الآن وبكم وبأي بونص؟). جمعُهما في شاشة كان يدفن
// الثاني خلف مبدّل، ويجعل زرّ الفلاتر واحداً لمجموعتي فلاتر مختلفتين.
class PhWarehouseCatalogPage extends ConsumerStatefulWidget {
  const PhWarehouseCatalogPage({super.key});

  @override
  ConsumerState<PhWarehouseCatalogPage> createState() =>
      _PhWarehouseCatalogPageState();
}

class _PhWarehouseCatalogPageState
    extends ConsumerState<PhWarehouseCatalogPage> {
  static const int _pageSize = 30;

  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<MedicineSearchResult> _results = [];
  final Set<String> _seenIds = {};
  int _rawOffset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _loading = true;
  String? _error;

  String _manufacturer = '';
  String? _warehouseId;
  String? _warehouseName;
  MedicineSearchSource _source = MedicineSearchSource.all;
  MedicineSearchSort _sort = MedicineSearchSort.byDefault;

  /// مفتاح السطر الجاري إضافته — لتعطيل زرّه وحده لا الشاشة كلها.
  String? _adding;

  int get _activeFilterCount =>
      (_source != MedicineSearchSource.all ? 1 : 0) +
      (_sort != MedicineSearchSort.byDefault ? 1 : 0) +
      (_manufacturer.isNotEmpty ? 1 : 0) +
      (_warehouseId != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _runSearch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
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
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      _runSearch(reset: false);
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _searchController.text.trim();
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _rawOffset = 0;
        _hasMore = true;
        _results.clear();
        _seenIds.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ref.read(medicineSearchRepositoryProvider).search(
            name: query.isEmpty ? null : query,
            manufacturer: _manufacturer.isEmpty ? null : _manufacturer,
            warehouseId: _warehouseId,
            source: _source,
            sort: _sort,
            limit: _pageSize,
            offset: reset ? 0 : _rawOffset,
          );
      if (!mounted) return;

      // التمييز بهويّة **السطر القابل للشراء** لا بصنف الكتالوج: المفتاح
      // بصنف الكتالوج يطوي نفس الدواء من مستودعات مختلفة في صفٍّ
      // واحد، فيختفي أرخصُها ولا يُعرف أيّ مستودعٍ يعني زرّ الإضافة.
      final unique = <MedicineSearchResult>[];
      for (final r in page.items) {
        final key = _lineKey(r);
        if (!_seenIds.contains(key)) {
          _seenIds.add(key);
          unique.add(r);
        }
      }

      setState(() {
        _rawOffset += page.items.length;
        _results.addAll(unique);
        _hasMore = page.items.length == _pageSize;
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

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty) return;
    _searchController.text = code;
    _runSearch(reset: true);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_WhFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhFilterSheet(
        source: _source,
        sort: _sort,
        manufacturer: _manufacturer,
        warehouseId: _warehouseId,
      ),
    );
    if (result == null || !mounted) return;
    if (result.source == _source &&
        result.sort == _sort &&
        result.manufacturer == _manufacturer &&
        result.warehouseId == _warehouseId) {
      return;
    }
    setState(() {
      _source = result.source;
      _sort = result.sort;
      _manufacturer = result.manufacturer;
      _warehouseId = result.warehouseId;
      _warehouseName = result.warehouseName;
    });
    _runSearch(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _source = MedicineSearchSource.all;
      _sort = MedicineSearchSort.byDefault;
      _manufacturer = '';
      _warehouseId = null;
      _warehouseName = null;
    });
    _runSearch(reset: true);
  }

  /// هويّة السطر القابل للشراء — صنف عرضٍ بعينه أو صنف تسعيرٍ مباشر.
  static String _lineKey(MedicineSearchResult r) => r.isOffer
      ? 'offer:${r.salesOfferItemId}'
      : 'wh:${r.warehouseMedicineId}';

  /// الكمية الافتراضية عند الإضافة: كمية العرض المعلنة — فالمستودع يعرض
  /// الصنف بكمية بعينها، والغالب أن الصيدلي يطلبها كما هي. والتسعير
  /// المباشر بلا كمية معلنة فيبدأ من واحد.
  static int _defaultQuantity(MedicineSearchResult r) {
    final declared = r.availableQuantity;
    if (declared == null || declared <= 0) return 1;
    return declared.round().clamp(1, 9999);
  }

  Future<void> _addToCart(MedicineSearchResult r) async {
    if (_adding != null) return;

    final qty = await showQuantityDialog(
      context,
      medicineName: r.medicineName,
      initialQuantity: _defaultQuantity(r),
      hint: r.isOffer && r.availableQuantity != null
          ? 'كمية العرض المعلنة: ${formatQuantity(r.availableQuantity!)} ${r.unit}'
          : null,
      // بوجود سلّم بونص يتولّى الحوار الكمية الابتدائية وخطوة الزيادة.
      tiers: r.bonusTiers,
      // الصنف ومستودعه وسعره: الحوار يعرض إجمالي ما سيُدفع عند الكمية
      // المختارة، فلا يُضيف الصيدلي ثمّ يكتشف المبلغ في السلّة.
      unit: r.unit,
      unitPrice: r.netUnitPrice ?? r.unitPrice,
      currency: r.currency,
      warehouseName: r.warehouseName,
    );
    if (qty == null || !mounted) return;

    setState(() => _adding = _lineKey(r));
    try {
      final notifier = ref.read(cartProvider.notifier);
      if (r.isOffer) {
        await notifier.addOfferItem(r.salesOfferItemId!, quantity: qty);
      } else {
        await notifier.addWarehouseMedicine(r.warehouseMedicineId!,
            quantity: qty);
      }
      if (!mounted) return;
      AppSnackbar.success(context, 'أُضيف «${r.medicineName}» إلى السلّة');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: InnerTopBar(
        title: 'كاتالوج المستودعات',
        trailing: CartButton(
          count: cartCount,
          onTap: () => context.push(TRoutes.phCart),
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
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: _searchController,
                    hint: 'ابحث بالاسم أو الباركود…',
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _runSearch(reset: true),
                    onScanTap: _scanBarcode,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FiltersBtn(count: _activeFilterCount, onTap: _openFilters),
              ],
            ),
          ),

          if (_activeFilterCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            // الفلاتر الفعّالة شرائحُ تُرفع بنقرة — فلا يُضطرّ الصيدلي إلى
            // فتح الورقة ليعرف لماذا قلّت النتائج ولا ليُلغي فلتراً واحداً.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_warehouseId != null) ...[
                      FilterChipCloseable(
                        label: _warehouseName ?? 'مستودع محدّد',
                        onRemove: () {
                          setState(() {
                            _warehouseId = null;
                            _warehouseName = null;
                          });
                          _runSearch(reset: true);
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (_manufacturer.isNotEmpty) ...[
                      FilterChipCloseable(
                        label: _manufacturer,
                        onRemove: () {
                          setState(() => _manufacturer = '');
                          _runSearch(reset: true);
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (_source != MedicineSearchSource.all) ...[
                      FilterChipCloseable(
                        label: _source.label,
                        onRemove: () {
                          setState(() => _source = MedicineSearchSource.all);
                          _runSearch(reset: true);
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (_sort != MedicineSearchSort.byDefault)
                      FilterChipCloseable(
                        label: _sort.label,
                        onRemove: () {
                          setState(() => _sort = MedicineSearchSort.byDefault);
                          _runSearch(reset: true);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppListSkeleton(variant: SkeletonVariant.row);
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: () => _runSearch(reset: true));
    }
    if (_results.isEmpty) {
      return UiEmpty(
        message: 'لا أدوية متاحة',
        description: 'لا مستودع في منطقتك سعّر هذا الدواء بعد — '
            'جرّب بحثاً مختلفاً أو مسح الفلاتر.',
        actionLabel: _activeFilterCount > 0 ? 'مسح الفلاتر' : null,
        onAction: _activeFilterCount > 0 ? _clearFilters : null,
      );
    }

    return ListView.builder(
      controller: _scroll,
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
        final r = _results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _WhCatalogCard(
            result: r,
            adding: _adding == _lineKey(r),
            onAdd: r.isUnpriced ? null : () => _addToCart(r),
            onOpenWarehouse: () =>
                context.push(TRoutes.phWarehouseProfile(r.supplyWarehouseId)),
            onComparePrices: r.catalogItemId == null
                ? null
                : () => context.push(TRoutes.phMedicineInWarehouses(
                      catalogItemId: r.catalogItemId!,
                      name: r.medicineName,
                    )),
          ),
        );
      },
    );
  }
}

// ── بطاقة صنف في كاتالوج المستودعات ──────────────────────────────────────
//
// الصفّ هنا **عرضٌ قابل للشراء** من مستودع بعينه لا «دواء» مجرّد: لذلك
// يحمل اسم بائعه وسعره بعملته وزرّ إضافته. ومن اسم المستودع يُفتح ملفه
// لاستعراض بقية أدويته وعروضه.
class _WhCatalogCard extends StatelessWidget {
  const _WhCatalogCard({
    required this.result,
    required this.adding,
    required this.onAdd,
    required this.onOpenWarehouse,
    this.onComparePrices,
  });

  final MedicineSearchResult result;
  final bool adding;

  /// `null` للصنف غير المسعَّر — يُعرَض ولا يُضاف (السلّة تُجمّد سعراً).
  final VoidCallback? onAdd;

  final VoidCallback onOpenWarehouse;
  final VoidCallback? onComparePrices;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final r = result;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // حدٌّ ذهبي لصفّ العرض يميّزه عن التسعير المباشر بنظرة.
        border: Border.all(color: r.isOffer ? tk.gold : cs.outline),
        boxShadow: tk.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.medicineName,
                      style: context.text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.specLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.specLine,
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // الشركة المصنّعة سطرٌ مستقلّ لا ذيلٌ في سطر التركيب:
                    // هي معيار اختيارٍ قائم بذاته (الصيدلي يَعرف شركاتٍ
                    // بعينها)، وحشرُها مع التركيب والشكل يُطيل السطر فيُبتَر.
                    if (r.manufacturerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AppIcon(AppIcons.package, size: 12, color: tk.hint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              r.manufacturerName,
                              style: context.text.labelSmall
                                  ?.copyWith(color: tk.hint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // السعر بعملة بائعه — بلا تحويل، فالرمز جزءٌ من الرقم.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (r.isUnpriced)
                    Text(
                      r.unpricedReason,
                      style: context.text.bodySmall?.copyWith(color: tk.hint),
                    )
                  else
                    Text(
                      formatMoneyWith(r.netUnitPrice!, r.currency),
                      style: context.priceStyle,
                    ),
                  if (r.isDerivedPrice)
                    Text(
                      'تقديري',
                      style:
                          context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // اسم المستودع مفتاحُ ملفه — «كل أدويته وعروضه» على بعد نقرة.
          InkWell(
            onTap: onOpenWarehouse,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  AppIcon(AppIcons.warehouse, size: 14, color: cs.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      r.warehouseLabel,
                      style: context.text.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppIcon(
                    AppIcons.chevronForwardRtl,
                    size: 14,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),

          if (r.hasBonus || (r.isOffer && r.availableQuantity != null)) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (r.hasBonus) BonusBadge(label: r.bonusLabel!),
                if (r.isOffer && r.availableQuantity != null)
                  StatusBadge(
                    label:
                        'الكمية ${formatQuantity(r.availableQuantity!)} ${r.unit}',
                    tone: StatusTone.neutral,
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (onComparePrices != null)
                Expanded(
                  child: AppButton(
                    label: 'قارن الأسعار',
                    icon: Icons.compare_arrows,
                    fullWidth: true,
                    compact: true,
                    variant: AppButtonVariant.text,
                    onPressed: onComparePrices,
                  ),
                ),
              if (onComparePrices != null) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: adding ? 'تُضاف…' : 'أضف للسلة',
                  icon: Icons.add_shopping_cart,
                  fullWidth: true,
                  compact: true,
                  onPressed: adding ? null : onAdd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ── نتيجة ورقة فلاتر كاتالوج المستودعات ─────────────────────────────────
// ── نتيجة ورقة فلاتر كاتالوج المستودعات ─────
class _WhFilters {
  const _WhFilters({
    required this.source,
    required this.sort,
    required this.manufacturer,
    required this.warehouseId,
    required this.warehouseName,
  });
  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;
  final String? warehouseId;
  final String? warehouseName;
}
// ── ورقة فلاتر كاتالوج المستودعات ──────
//
// أربعة فلاتر في ورقة واحدة. الشكل السابق كان صفّاً مستقلاً لكل خيار —
// ثمانية صفوف لاختيارين — فيُقرأ قائمةَ إعدادات طويلة لا مجموعةَ خيارات.
// هنا: الخياران القصيران (الترتيب والمصدر) شرائحُ في سطر يُقرأ بنظرة،
// والقائمتان الطويلتان (المستودع والشركة) خلف صفٍّ واحد يُفتح عند الحاجة
// فلا يزاحم غيره وهو مطويّ.
class _WhFilterSheet extends ConsumerStatefulWidget {
  const _WhFilterSheet({
    required this.source,
    required this.sort,
    required this.manufacturer,
    required this.warehouseId,
  });
  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;
  final String? warehouseId;

  @override
  ConsumerState<_WhFilterSheet> createState() => _WhFilterSheetState();
}
class _WhFilterSheetState extends ConsumerState<_WhFilterSheet> {
  late MedicineSearchSource _source = widget.source;
  late MedicineSearchSort _sort = widget.sort;
  late String? _pickedMfr =
      widget.manufacturer.isEmpty ? null : widget.manufacturer;
  late String? _pickedWarehouseId = widget.warehouseId;

  List<String> _manufacturers = [];
  List<WarehousePicker> _warehouses = [];
  bool _loadingMfr = true;
  bool _loadingWh = true;

  @override
  void initState() {
    super.initState();
    _loadManufacturers();
    _loadWarehouses();
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

  Future<void> _loadWarehouses() async {
    try {
      final list =
          await ref.read(warehouseRepositoryProvider).getActiveWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        _loadingWh = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWh = false);
    }
  }

  WarehousePicker? get _pickedWarehouse {
    final id = _pickedWarehouseId;
    if (id == null) return null;
    for (final w in _warehouses) {
      if (w.id == id) return w;
    }
    return null;
  }

  bool get _isClean =>
      _source == MedicineSearchSource.all &&
      _sort == MedicineSearchSort.byDefault &&
      _pickedMfr == null &&
      _pickedWarehouseId == null;

  /// القائمتان الطويلتان تُفتحان **ورقةً منبثقة** لا قائمةً مضمَّنة:
  /// مائة مستودع داخل ورقة الفلاتر تدفع بقيّة الفلاتر خارج الشاشة،
  /// وتجعل التمرير واحداً للورقة والقائمة معاً. والورقة تصعد من الأسفل
  /// بارتفاعها الخاص، فلا تزاحم شيئاً.
  Future<void> _pickWarehouse() async {
    final picked = await showOptionPickerSheet(
      context,
      title: 'اختر المستودع',
      searchHint: 'ابحث باسم المستودع أو مدينته…',
      allLabel: 'كل المستودعات',
      selectedId: _pickedWarehouseId,
      loading: _loadingWh,
      options: [
        for (final w in _warehouses)
          PickerOption(
            id: w.id,
            icon: AppIcons.warehouse,
            // المدينة والعملة في السطر نفسه: الصيدلي يختار مستودعاً
            // ليرى أسعاره، فعملته جزءٌ من القرار.
            title: '${w.name} — ${w.city}'
                ' · ${currencySymbol(w.pricingCurrency)}',
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedWarehouseId = picked.id);
  }

  Future<void> _pickManufacturer() async {
    final picked = await showOptionPickerSheet(
      context,
      title: 'اختر الشركة المصنّعة',
      searchHint: 'ابحث في الشركات…',
      allLabel: 'كل الشركات',
      selectedId: _pickedMfr,
      loading: _loadingMfr,
      options: [
        for (final name in _manufacturers)
          PickerOption(id: name, icon: AppIcons.package, title: name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedMfr = picked.id);
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
                  Text('تصفية النتائج', style: context.text.headlineSmall),
                  const Spacer(),
                  TextButton(
                    onPressed: _isClean
                        ? null
                        : () => setState(() {
                              _source = MedicineSearchSource.all;
                              _sort = MedicineSearchSort.byDefault;
                              _pickedMfr = null;
                              _pickedWarehouseId = null;
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
                    const SheetLabel('الترتيب'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final v in MedicineSearchSort.values)
                          AppFilterChip(
                            label: v.label,
                            selected: _sort == v,
                            onTap: () => setState(() => _sort = v),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const SheetLabel('المصدر'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final v in MedicineSearchSource.values)
                          AppFilterChip(
                            label: v.label,
                            selected: _source == v,
                            onTap: () => setState(() => _source = v),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    PickerRow(
                      icon: AppIcons.warehouse,
                      title: 'المستودع',
                      value: _pickedWarehouse?.name ?? 'كل المستودعات',
                      onTap: _pickWarehouse,
                      onClear: _pickedWarehouseId == null
                          ? null
                          : () => setState(() => _pickedWarehouseId = null),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    PickerRow(
                      icon: AppIcons.package,
                      title: 'الشركة المصنّعة',
                      value: _pickedMfr ?? 'كل الشركات',
                      onTap: _pickManufacturer,
                      onClear: _pickedMfr == null
                          ? null
                          : () => setState(() => _pickedMfr = null),
                    ),
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
                label: 'عرض النتائج',
                onPressed: () => Navigator.pop(
                  context,
                  _WhFilters(
                    source: _source,
                    sort: _sort,
                    manufacturer: _pickedMfr ?? '',
                    warehouseId: _pickedWarehouseId,
                    warehouseName: _pickedWarehouse?.name,
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
// عنوان قسم داخل ورقة الفلاتر.
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: context.text.titleSmall),
      );
}
// صفّ يعرض الاختيار الحالي ويفتح قائمته — مطويّاً يشغل سطراً واحداً.
class PickerRow extends StatelessWidget {
  const PickerRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final AppIcons icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final picked = onClear != null;

    return Material(
      color: picked ? tk.brandSurface : cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: picked ? cs.primary : cs.outline),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 18, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: context.text.bodyMedium),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value,
                  style: context.text.bodySmall?.copyWith(
                    color: picked ? cs.primary : tk.hint,
                    fontWeight: picked ? FontWeight.w600 : null,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (picked)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'إلغاء التحديد',
                )
              else
                // الصفّ يفتح ورقةً منبثقة لا قائمةً تنطوي تحته،
                // فالأيقونة تقول «اختر» لا «افتح لأسفل».
                Icon(Icons.unfold_more, size: 18, color: tk.hint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ورقة اختيار منبثقة ───────────────────────────────────────────────────

/// خيار واحد في ورقة الاختيار.
class PickerOption {
  const PickerOption({
    required this.id,
    required this.icon,
    required this.title,
  });

  final String id;
  final AppIcons icon;
  final String title;
}

/// نتيجة الورقة. [id] فارغٌ يعني أن «الكل» اختير — وهو غير إغلاق الورقة
/// بلا اختيار (تُعيد `null` كاملةً)، فلا يُفسَّر التراجع إلغاءً للتحديد.
class PickerResult {
  const PickerResult(this.id);
  final String? id;
}

/// ورقة اختيار منبثقة قابلة للبحث — للمستودع والشركة المصنّعة معاً.
///
/// منبثقة لا مضمَّنة: مئةُ مستودع داخل ورقة الفلاتر تدفع بقيّة الفلاتر خارج
/// الشاشة، ويصير التمرير واحداً للورقة والقائمة معاً فيتنازعان. وهنا تصعد
/// بارتفاعها الخاص، ولها حقل بحثها وتمريرها المستقلّ.
Future<PickerResult?> showOptionPickerSheet(
  BuildContext context, {
  required String title,
  required String searchHint,
  required String allLabel,
  required String? selectedId,
  required bool loading,
  required List<PickerOption> options,
}) {
  return showModalBottomSheet<PickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OptionPickerSheet(
      title: title,
      searchHint: searchHint,
      allLabel: allLabel,
      selectedId: selectedId,
      loading: loading,
      options: options,
    ),
  );
}

class _OptionPickerSheet extends StatefulWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.searchHint,
    required this.allLabel,
    required this.selectedId,
    required this.loading,
    required this.options,
  });

  final String title;
  final String searchHint;
  final String allLabel;
  final String? selectedId;
  final bool loading;
  final List<PickerOption> options;

  @override
  State<_OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<_OptionPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PickerOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final filtered = _filtered;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  Expanded(
                    child: Text(widget.title, style: context.text.titleLarge),
                  ),
                  Text(
                    '${widget.options.length}',
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                ],
              ),
            ),

            // البحث يظهر حين تستحقّه القائمة: أربعة خيارات تُقرأ بلا بحث.
            if (widget.options.length > 4) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: AppTextField(
                  controller: _search,
                  hint: widget.searchHint,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: widget.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.x2l),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        MediaQuery.of(context).viewInsets.bottom +
                            AppSpacing.xl,
                      ),
                      children: [
                        FilterOptionRow(
                          icon: AppIcons.search,
                          title: widget.allLabel,
                          selected: widget.selectedId == null,
                          onTap: () =>
                              Navigator.pop(context, const PickerResult(null)),
                        ),
                        for (final o in filtered) ...[
                          const SizedBox(height: AppSpacing.xs),
                          FilterOptionRow(
                            icon: o.icon,
                            title: o.title,
                            selected: widget.selectedId == o.id,
                            onTap: () =>
                                Navigator.pop(context, PickerResult(o.id)),
                          ),
                        ],
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.lg),
                            child: Text(
                              'لا نتائج مطابقة',
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint),
                            ),
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
