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
  const PhPriceSearchPage({this.initialQuery, super.key});

  /// نصّ بحث قادم من شاشة أخرى (مثل بحث الرئيسية) — يُعبَّأ ويُنفَّذ مباشرة.
  final String? initialQuery;

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
  MedicineSearchSort _sort = MedicineSearchSort.byDefault;

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
        name: _searchController.text,
        source: _source,
        sort: _sort,
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
    final applied = await showModalBottomSheet<(MedicineSearchSource, MedicineSearchSort)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceFiltersSheet(source: _source, sort: _sort),
    );
    if (applied == null || !mounted) return;
    if (applied.$1 == _source && applied.$2 == _sort) return;
    setState(() {
      _source = applied.$1;
      _sort = applied.$2;
    });
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
      (_sort != MedicineSearchSort.byDefault ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      appBar: InnerTopBar(
        title: 'بحث الأسعار',
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
              hint: 'ابحث عن دواء، مادة فعالة، أو مستودع…',
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _run(reset: true),
              onScanTap: _scanBarcode,
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

  Widget _buildBody() {
    if (_loading) return const LoadingState();
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
    final offers = _results.where((r) => r.isOffer).toList();
    final direct = _results.where((r) => !r.isOffer).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        if (grouped) ...[
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
        ] else
          for (final r in _results) _card(r),

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
      onOfferDetails: r.salesOfferId == null
          ? null
          : () => context.push(TRoutes.phOfferDetail(r.salesOfferId!)),
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
    this.onOfferDetails,
  });

  final MedicineSearchResult result;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback? onOfferDetails;

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
            children: [
              SizedBox(
                height: 36,
                child: AppButton(
                  label: 'أضف للسلة',
                  icon: Icons.add,
                  fullWidth: false,
                  loading: adding,
                  onPressed: onAdd,
                ),
              ),
              if (onOfferDetails != null) ...[
                const SizedBox(width: AppSpacing.md),
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
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'سعر الوحدة',
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                  Text(
                    formatMoneyWith(r.netUnitPrice, r.currency),
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

// لوحة فلاتر الأسعار (Figma: الصيدلي / لوحة فلاتر الأسعار) — المصدر
// والترتيب، مع «مسح الكل» وزر «تطبيق» واحد.
class _PriceFiltersSheet extends StatefulWidget {
  const _PriceFiltersSheet({required this.source, required this.sort});

  final MedicineSearchSource source;
  final MedicineSearchSort sort;

  @override
  State<_PriceFiltersSheet> createState() => _PriceFiltersSheetState();
}

class _PriceFiltersSheetState extends State<_PriceFiltersSheet> {
  late MedicineSearchSource _source = widget.source;
  late MedicineSearchSort _sort = widget.sort;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          10,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            Row(
              children: [
                Expanded(
                  child: Text('فلاتر البحث', style: context.text.headlineSmall),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _source = MedicineSearchSource.all;
                    _sort = MedicineSearchSort.byDefault;
                  }),
                  child: const Text('مسح الكل'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            Text('المصدر', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
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
            Text('الترتيب', style: context.text.titleMedium),
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

            const SizedBox(height: AppSpacing.x2l),
            AppButton(
              label: 'تطبيق',
              onPressed: () => Navigator.pop(context, (_source, _sort)),
            ),
          ],
        ),
      ),
    );
  }
}
