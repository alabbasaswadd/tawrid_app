import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';
import 'package:tawrid_app/repositories/medicine_catalog_repository.dart';
import 'package:tawrid_app/repositories/medicine_search_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// بحث الأسعار (Figma: الصيدلي / بحث الأسعار).
//
// يدمج مصدرين: أصناف داخل عروض بيع سارية، وتسعير مباشر من المستودعات التي
// تخدم مدينة الصيدلية. الخادم هو من يدمج ويرتّب — والشاشة تعرض نتائجه
// مقسومة إلى قسمين يسمّيان مصدرهما، لأن «ضمن عرض» و«سعر مباشر» قراران
// مختلفان ولو تساوى الرقمان.
class PhPriceSearchPage extends ConsumerStatefulWidget {
  const PhPriceSearchPage({
    this.initialQuery,
    this.warehouseId,
    this.warehouseName,
    this.catalogItemId,
    this.includeAlternatives = false,
    super.key,
  });

  /// نصّ بحث قادم من شاشة أخرى (مثل بحث الرئيسية) — يُعبَّأ ويُنفَّذ مباشرة.
  final String? initialQuery;

  /// يحصر البحث بمستودع واحد — يُفتح من ملف المستودع. الخادم يفلتر
  /// بالمعرّف، والاسم للعنوان وحده.
  final String? warehouseId;
  final String? warehouseName;

  /// مقارنة صنف بعينه عبر كل المستودعات — من زرّ «مقارنة الأسعار» في بطاقة
  /// نتيجة. يحصر المطابقة بصنف الكتالوج، والترتيب الافتراضي هنا بالسعر.
  final String? catalogItemId;

  /// يضمّ البدائل: أدويةً أخرى بالتركيب العلمي نفسه، في قسمٍ مستقلّ تحت
  /// الدواء المطلوب. يحتاج [catalogItemId] — من دونه لا يعرف الخادم
  /// أيّ تركيب يقصد، فلا بدائل.
  final bool includeAlternatives;

  @override
  ConsumerState<PhPriceSearchPage> createState() => _PhPriceSearchPageState();
}

class _PhPriceSearchPageState extends ConsumerState<PhPriceSearchPage> {
  static const int _pageSize = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  final List<MedicineSearchResult> _results = [];
  MedicineSearchSource _source = MedicineSearchSource.all;
  late MedicineSearchSort _sort = widget.catalogItemId != null
      ? MedicineSearchSort.priceLowToHigh
      : MedicineSearchSort.byDefault;
  String _manufacturer = '';

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  /// معرّف النتيجة الجاري إضافتها — يُظهر التحميل على بطاقتها وحدها.
  String? _adding;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    _scrollController.addListener(_onScroll);
    _run(reset: true);
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
    // نصف ثانية: كتابة اسم دواء عربي لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(reset: true));
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 320) _run(reset: false);
  }

  Future<void> _run({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ref.read(medicineSearchRepositoryProvider).search(
        // صنف محدَّد بمعرّفه لا يحتاج فلتر الاسم أيضاً — نصّه فقط للسياق في
        // الحقل، وتفعيله معاً قد يُسقط صنفاً اسمه الحرّ (من عرض) لا يطابق
        // نصياً اسم الكتالوج الذي يحمل معرّفه نفسه.
        name: widget.catalogItemId != null ? null : _searchController.text,
        catalogItemId: widget.catalogItemId,
        warehouseId: widget.warehouseId,
        manufacturer: _manufacturer.isEmpty ? null : _manufacturer,
        source: _source,
        sort: _sort,
        includeAlternatives: widget.includeAlternatives,
        limit: _pageSize,
        offset: reset ? 0 : _results.length,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _results.clear();
        _results.addAll(page.items);
        _hasMore = _results.length < page.totalCount;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // ترتيب «الأقرب» بلا موقع مسجَّل يردّه الخادم برسالة صريحة؛
        // نعرضها ونعود إلى الترتيب الافتراضي بدل ترك الشاشة عالقة عليه.
        _error = ApiException.from(e).message;
        _loading = false;
        _loadingMore = false;
      });
      if (_sort == MedicineSearchSort.nearest) {
        setState(() => _sort = MedicineSearchSort.byDefault);
      }
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _searchController.text = code;
    _run(reset: true);
  }

  Future<void> _openFilters() async {
    final applied = await showModalBottomSheet<_AppliedPriceFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceFiltersSheet(
        source: _source,
        sort: _sort,
        manufacturer: _manufacturer,
        warehouseId: widget.warehouseId,
      ),
    );
    if (applied == null || !mounted) return;
    if (applied.source == _source &&
        applied.sort == _sort &&
        applied.manufacturer == _manufacturer) {
      return;
    }
    setState(() {
      _source = applied.source;
      _sort = applied.sort;
      _manufacturer = applied.manufacturer;
    });
    _run(reset: true);
  }

  /// رفع فلتر الشركة من شريحته مباشرةً — بلا فتح ورقة الفلاتر.
  void _clearManufacturer() {
    setState(() => _manufacturer = '');
    _run(reset: true);
  }

  Future<void> _addToCart(MedicineSearchResult r) async {
    final key = _keyOf(r);
    if (_adding != null) return;
    setState(() => _adding = key);
    try {
      final notifier = ref.read(cartProvider.notifier);
      if (r.isOffer) {
        await notifier.addOfferItem(r.salesOfferItemId!);
      } else {
        await notifier.addWarehouseMedicine(r.warehouseMedicineId!);
      }
      if (!mounted) return;
      AppSnackbar.success(context, 'أُضيف «${r.medicineName}» إلى السلّة');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _adding = null);
    }
  }

  static String _keyOf(MedicineSearchResult r) => r.isOffer
      ? 'offer:${r.salesOfferItemId}'
      : 'wh:${r.warehouseMedicineId}';

  /// عدد الفلاتر المختلفة عن الافتراضي — شارة زرّ الفلاتر.
  int get _activeFilters =>
      (_source != MedicineSearchSource.all ? 1 : 0) +
      (_sort != MedicineSearchSort.byDefault ? 1 : 0) +
      (_manufacturer.isNotEmpty ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartCountProvider);
    final scoped = widget.warehouseId != null;

    return Scaffold(
      appBar: InnerTopBar(
        title: widget.includeAlternatives
            ? 'توفّره في المستودعات'
            : scoped
                ? 'البحث في المستودع'
                : 'بحث الأسعار',
        // زر السلّة في الطرف المقابل لزر الرجوع (Figma).
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
            child: AppSearchBar(
              controller: _searchController,
              hint: scoped
                  ? 'ابحث عن دواء داخل هذا المستودع…'
                  : 'ابحث عن دواء، مادة فعالة، أو مستودع…',
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _run(reset: true),
              onScanTap: _scanBarcode,
            ),
          ),

          // الفلتر المطبَّق يبقى مرئياً طوال البحث: نتيجة واحدة بلا سياق
          // تُقرأ كأنها كل ما في السوق.
          if (_manufacturer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _ActiveFilterChip(
                  label: _manufacturer,
                  onRemove: _clearManufacturer,
                ),
              ),
            ),

          // صفّ الفلاتر: زر دائري بشارة عدد الفلاتر، واسم الترتيب الحالي.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FiltersButton(count: _activeFilters, onTap: _openFilters),
                const SizedBox(width: AppSpacing.md),
                InkWell(
                  onTap: _openFilters,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sort == MedicineSearchSort.byDefault
                            ? 'الترتيب الافتراضي'
                            : _sort.label,
                        style: context.text.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        AppIcons.chevronDown,
                        size: 14,
                        color: context.colors.onSurface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// «من العروض» ثم «تسعير مباشر» داخل مجموعةٍ واحدة من النتائج.
  List<Widget> _sourceSections(List<MedicineSearchResult> rows, bool grouped) {
    if (!grouped) return [for (final r in rows) _card(r)];

    final offers = rows.where((r) => r.isOffer).toList();
    final direct = rows.where((r) => !r.isOffer).toList();
    return [
      if (offers.isNotEmpty) ...[
        Text('من العروض', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final r in offers) _card(r),
      ],
      if (direct.isNotEmpty) ...[
        if (offers.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        Text('تسعير مباشر من المستودعات', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final r in direct) _card(r),
      ],
    ];
  }

  /// بحث التوفّر يقسم أولاً بنوع المطابقة — الدواء المطلوب ثم ما يشاركه
  /// التركيب — وتقسيم المصدر يبقى داخل كل مجموعة: «بديل ضمن عرض» و«الدواء
  /// نفسه بسعر مباشر» قراران مختلفان لا يصحّ خلطهما في قائمة واحدة.
  List<Widget> _matchSections(bool grouped) {
    if (!widget.includeAlternatives) return _sourceSections(_results, grouped);

    final same = _results.where((r) => !r.isAlternative).toList();
    final alt = _results.where((r) => r.isAlternative).toList();

    return [
      if (same.isNotEmpty) ...[
        const AppSectionHeader(title: 'هذا الدواء'),
        const SizedBox(height: AppSpacing.md),
        ..._sourceSections(same, grouped),
      ] else if (alt.isNotEmpty)
        // غياب الدواء نفسه خبرٌ يخصّ الصيدلي: بلا هذا السطر تبدو البدائل
        // وكأنها هو.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'لا مستودع يخدم مدينتك يعرض هذا الدواء بعينه — وهذه أدوية '
            'تحمل تركيبه العلمي نفسه.',
            style: context.text.bodySmall?.copyWith(color: context.tokens.hint),
          ),
        ),
      if (alt.isNotEmpty) ...[
        if (same.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(
          title: 'بدائل بالتركيب العلمي نفسه',
          subtitle: 'المادة الفعّالة ذاتها بشركة أو شكل دوائي مختلف — '
              'راجِع الجرعة قبل الاستبدال.',
        ),
        const SizedBox(height: AppSpacing.md),
        ..._sourceSections(alt, grouped),
      ],
    ];
  }

  Widget _buildBody() {
    // هيكل بطاقات شبيه بنتائج البحث — انتظارٌ يُظهر شكل ما سيأتي
    // بدل دوّارة لا تقول شيئاً.
    if (_loading) return const AppListSkeleton(count: 4);
    if (_error != null && _results.isEmpty) {
      return ErrorState(message: _error!, onRetry: () => _run(reset: true));
    }

    if (_results.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.x3l),
          UiEmpty(
            message: 'لا أسعار مطابقة',
            description: _source == MedicineSearchSource.offersOnly
                ? 'لا عرض ساري يتضمّن هذا الدواء ضمن ما يغطّي منطقتك — جرّب '
                      'إظهار التسعير المباشر أيضاً.'
                : 'لا مستودع يخدم مدينتك سعّر هذا الدواء بعد.',
            actionLabel: _activeFilters > 0 ? 'مسح الفلاتر' : null,
            onAction: _activeFilters > 0
                ? () {
                    setState(() {
                      _source = MedicineSearchSource.all;
                      _sort = MedicineSearchSort.byDefault;
                      _manufacturer = '';
                    });
                    _run(reset: true);
                  }
                : null,
          ),
        ],
      );
    }

    // الترتيب المسطّح (سعراً أو مسافةً) طلبٌ صريح بخلط المصدرين، فتقسيمه
    // إلى قسمين يناقضه. القسمان للترتيب الافتراضي وحده.
    final grouped = _sort == MedicineSearchSort.byDefault;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        ..._matchSections(grouped),

        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.sm),
        Text(
          'الأسعار بحسب ما حدّده كل مستودع وقد تتغيّر — السعر النهائي هو ما '
          'يظهر عند إتمام الطلب.',
          style: context.text.bodySmall?.copyWith(color: context.tokens.hint),
        ),
      ],
    );
  }

  Widget _card(MedicineSearchResult r) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: _PriceResultCard(
      result: r,
      adding: _adding == _keyOf(r),
      onAdd: () => _addToCart(r),
      onRequestQuote: () => context.push(TRoutes.phCreateTender),
      onOfferDetails: r.salesOfferId == null
          ? null
          : () => context.push(TRoutes.phOfferDetail(r.salesOfferId!)),
      // صفحة المقارنة نفسها محصورة بصنف واحد أصلاً — لا حاجة للزرّ فيها.
      onComparePrices: widget.catalogItemId != null
          ? null
          : () => context.push(TRoutes.phPriceCompareItem(
                catalogItemId: r.catalogItemId,
                name: r.medicineName,
              )),
    ),
  );
}

// بطاقة نتيجة سعر (Figma: بطاقة نتيجة سعر): اسم الدواء وسطره الثانوي، ثم
// المستودع والمسافة، ثم فاصل، ثم زر «أضف للسلة» وسعر الوحدة.
// نتيجة العرض تحمل حدّاً ذهبياً وشارة بونص ورابط تفاصيل العرض — فرقٌ يجب
// أن يُرى قبل الضغط، لا بعده.
class _PriceResultCard extends StatelessWidget {
  const _PriceResultCard({
    required this.result,
    required this.adding,
    required this.onAdd,
    required this.onRequestQuote,
    this.onOfferDetails,
    this.onComparePrices,
  });

  final MedicineSearchResult result;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onRequestQuote;
  final VoidCallback? onOfferDetails;

  /// بحث عن نفس الصنف عبر كل المستودعات — لا يظهر داخل صفحة مقارنة أصلاً
  /// (مُمرَّر null حين تكون الصفحة نفسها محصورة بصنف واحد بالفعل).
  final VoidCallback? onComparePrices;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final r = result;
    final hasBonus = r.bonusPercentage != null && r.bonusPercentage! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: r.isOffer ? tk.gold : cs.outline),
        boxShadow: tk.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.specLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.specLine,
                        style: context.text.labelSmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (r.isOffer && r.salesOfferTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ضمن عرض: ${r.salesOfferTitle}',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (hasBonus) ...[
                const SizedBox(width: AppSpacing.sm),
                BonusBadge(
                  label: 'بونص ${r.bonusPercentage!.toStringAsFixed(0)}٪',
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _meta(context, AppIcons.warehouse, r.warehouseLabel),
              if (r.distanceKm != null)
                _meta(
                  context,
                  AppIcons.mapPin,
                  '${r.distanceKm!.toStringAsFixed(1)} كم',
                ),
              if (r.isOffer && r.offerExpiresAt != null)
                _meta(
                  context,
                  AppIcons.clock,
                  offerExpiryText(r.offerExpiresAt!),
                ),
            ],
          ),

          if (r.minimumOrderAmount != null && r.minimumOrderAmount! > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            // الحدّ الأدنى يُعرَض هنا لا عند الرفض: قرار الإضافة يحتاجه الآن.
            Text(
              'حدّ أدنى للطلب: '
              '${formatMoneyWith(r.minimumOrderAmount!, r.currency)}',
              style: context.text.labelSmall?.copyWith(color: tk.hint),
            ),
          ],

          const SizedBox(height: 10),
          Divider(color: cs.outline, height: 1),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مجموعة الأزرار في مساحة مرنة تلتفّ بسطر ثانٍ عند الازدحام
              // (ثلاثة أزرار محتملة + رابط التفاصيل) بدل أن تفيض عن البطاقة.
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // الصنف غير المسعَّر يُعرَض ليعرف الصيدلي أن المستودع
                    // يتعامل به، لكن السلّة تُجمِّد سعراً فلا تقبله —
                    // فيُستبدل زرّ الإضافة بمخرج مفيد: طلب تسعيره.
                    if (r.isUnpriced)
                      AppButton(
                        label: 'اطلب تسعيره',
                        icon: Icons.request_quote_outlined,
                        fullWidth: false,
                        compact: true,
                        variant: AppButtonVariant.tonal,
                        onPressed: onRequestQuote,
                      )
                    else
                      AppButton(
                        label: 'أضف للسلة',
                        icon: Icons.add,
                        fullWidth: false,
                        compact: true,
                        loading: adding,
                        onPressed: onAdd,
                      ),
                    if (onComparePrices != null)
                      AppButton(
                        label: 'مقارنة الأسعار',
                        icon: Icons.compare_arrows,
                        fullWidth: false,
                        compact: true,
                        variant: AppButtonVariant.tonal,
                        onPressed: onComparePrices,
                      ),
                    if (onOfferDetails != null)
                      InkWell(
                        onTap: onOfferDetails,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              AppIcons.chevronForwardRtl,
                              size: 14,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'تفاصيل العرض',
                              style: context.text.bodySmall?.copyWith(
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // السعر المشتقّ سعرٌ يُشترى به، لكن تسميته تقول مصدره:
                    // قد يعدّله المستودع متى أدخل سعره يدوياً.
                    r.isDerivedPrice ? 'سعر تقديري' : 'سعر الوحدة',
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                  if (r.isUnpriced)
                    Text(
                      'لم يُسعَّر بعد',
                      style: context.text.bodyMedium?.copyWith(color: tk.hint),
                    )
                  else
                    Text(
                      formatMoneyWith(r.netUnitPrice!, r.currency),
                      style: context.priceStyle,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, AppIcons icon, String text) {
    final tk = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: tk.hint),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall?.copyWith(color: tk.hint)),
      ],
    );
  }
}

// زر الفلاتر الدائري مع شارة عدد الفلاتر المفعّلة (Figma: زر الفلاتر).
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onTap});

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
            start: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: tk.brandDeep, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$count',
                  style: context.text.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── لوحة فلاتر الأسعار ───────────────────────────────────────────────────
// (Figma: الصيدلي / لوحة فلاتر الأسعار) — المستودع والشركة المصنّعة والمصدر
// والترتيب، مع «مسح الكل» وزر «تطبيق» واحد.

// نتيجة ورقة الفلاتر — سجلّ واحد بدل صفّ مجهول الأسماء، فإضافة فلتر
// جديد لا تُربك ترتيب الحقول عند الاستدعاء.
class _AppliedPriceFilters {
  const _AppliedPriceFilters({
    required this.source,
    required this.sort,
    required this.manufacturer,
  });

  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;
}

class _PriceFiltersSheet extends ConsumerStatefulWidget {
  const _PriceFiltersSheet({
    required this.source,
    required this.sort,
    required this.manufacturer,
    this.warehouseId,
  });

  final MedicineSearchSource source;
  final MedicineSearchSort sort;
  final String manufacturer;

  /// المستودع المحصور به البحث — يأتي من شاشة المستودع ولا يُغيَّر من هنا.
  /// يُستعمل لتحميل شركات ذلك المستودع وحدها بدل كل شركات الكتالوج.
  final String? warehouseId;

  @override
  ConsumerState<_PriceFiltersSheet> createState() => _PriceFiltersSheetState();
}

class _PriceFiltersSheetState extends ConsumerState<_PriceFiltersSheet> {
  /// سقف الخيارات المعروضة قبل الإحالة إلى حقل البحث — قائمة بلا سقف
  /// تبتلع الورقة كلها، وقائمة مقصوصة بلا إخبار تُخفي خيارات موجودة.
  static const int _maxOptions = 8;

  late MedicineSearchSource _source = widget.source;
  late MedicineSearchSort _sort = widget.sort;
  late String? _pickedMfr =
      widget.manufacturer.isEmpty ? null : widget.manufacturer;

  final _mfrSearchCtrl = TextEditingController();

  List<String> _manufacturers = [];
  bool _loadingMfr = false;

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

  // داخل مستودع واحد: شركاته الفعلية وحدها. غير محصور: كل شركات الكتالوج.
  Future<void> _loadManufacturers() async {
    setState(() => _loadingMfr = true);
    try {
      final warehouseId = widget.warehouseId;
      final list = warehouseId != null
          ? await ref
              .read(medicineSearchRepositoryProvider)
              .getWarehouseManufacturers(warehouseId)
          : await ref.read(medicineCatalogRepositoryProvider).getManufacturers();
      if (!mounted) return;
      setState(() {
        _manufacturers = list;
        _loadingMfr = false;
        // شركة مختارة لا يبيعها المستودع الجديد ليست فلتراً بل نتيجة صفرية.
        if (_pickedMfr != null && !list.contains(_pickedMfr)) _pickedMfr = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMfr = false);
    }
  }

  List<String> get _filteredManufacturers {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Expanded(
                    child:
                        Text('فلاتر البحث', style: context.text.headlineSmall),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _source = MedicineSearchSource.all;
                        _sort = MedicineSearchSort.byDefault;
                        _pickedMfr = null;
                        _mfrSearchCtrl.clear();
                      });
                    },
                    child: const Text('مسح الكل'),
                  ),
                ],
              ),
            ),

            // الورقة تطول بقائمتي المستودعات والشركات — المحتوى يتمرّر
            // وزرّ التطبيق يبقى مثبّتاً أسفلها فلا يُطارَد بالتمرير.
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
                    _section(context, 'الشركة المصنّعة'),
                    const SizedBox(height: AppSpacing.sm),
                    _manufacturerSection(context),

                    const SizedBox(height: AppSpacing.lg),
                    _section(context, 'المصدر'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in MedicineSearchSource.values)
                          AppFilterChip(
                            label: s.label,
                            selected: _source == s,
                            onTap: () => setState(() => _source = s),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _section(context, 'الترتيب'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in MedicineSearchSort.values)
                          AppFilterChip(
                            label: s.label,
                            selected: _sort == s,
                            onTap: () => setState(() => _sort = s),
                          ),
                      ],
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
                label: 'تطبيق',
                onPressed: () => Navigator.pop(
                  context,
                  _AppliedPriceFilters(
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

  Widget _section(BuildContext context, String title) =>
      Text(title, style: context.text.titleMedium);

  // ── قائمة الشركات المصنّعة ─────────────────────────────────────────────
  Widget _manufacturerSection(BuildContext context) {
    final tk = context.tokens;

    if (_loadingMfr) {
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

    if (_manufacturers.isEmpty) {
      return Text(
        widget.warehouseId == null
            ? 'لا شركات مسجَّلة بعد'
            : 'لا شركات مسجَّلة لهذا المستودع بعد',
        style: context.text.bodySmall?.copyWith(color: tk.hint),
      );
    }

    final all = _filteredManufacturers;
    final shown = all.take(_maxOptions).toList();
    final hidden = all.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        if (all.isEmpty && _mfrSearchCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'لا شركة تطابق بحثك',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
          ),

        for (final name in shown) ...[
          const SizedBox(height: AppSpacing.sm),
          _FilterOptionRow(
            icon: AppIcons.package,
            title: name,
            selected: _pickedMfr == name,
            onTap: () => setState(
                () => _pickedMfr = _pickedMfr == name ? null : name),
          ),
        ],

        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'و $hidden شركة أخرى — استخدم البحث للتضييق',
              style: context.text.labelSmall?.copyWith(color: tk.hint),
            ),
          ),
      ],
    );
  }
}

// سطر خيار في قائمة فلتر: أيقونة في مربّع، عنوان وسطر وصف، وعلامة اختيار.
// المختار يُعلَّم بالحدّ ولون السطح معاً لا باللون وحده.
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
                child: Text(
                  title,
                  style: context.text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

// شريحة فلتر مطبَّق — اسم الشركة المصنّعة ظاهراً طوال البحث مع × لرفعه.
// النتيجة بلا سياق فلترها تُقرأ كأنها كل ما في السوق.
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
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
          AppIcon(AppIcons.package, size: 14, color: cs.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(color: cs.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: AppIcon(AppIcons.x, size: 12, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}
