import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// الشرائح السريعة (Figma: فلاتر سريعة). ثلاث منها تنعكس على الخادم،
// و«بونص عرض كامل» تنقية محلّية: الخادم يعرف `hasBonus` واحداً يجمع
// المستويين، والتمييز بينهما يأتي من حقول الملخّص.
enum _QuickFilter {
  all('الكل'),
  itemBonus('بونص الأصناف'),
  offerBonus('بونص عرض كامل'),
  expiring('قريب الانتهاء');

  const _QuickFilter(this.label);
  final String label;
}

// حالة التصفية المتقدّمة كما تظهر في ورقة الفلاتر وزرّ الشريط العلوي.
class _OfferFilters {
  const _OfferFilters({
    this.quick = _QuickFilter.all,
    this.sort = OfferSort.newest,
    this.minPrice,
    this.maxPrice,
    this.dosageForm,
  });

  final _QuickFilter quick;
  final OfferSort sort;
  final double? minPrice;
  final double? maxPrice;
  final DosageForm? dosageForm;

  // ما يُحتسب في شارة زرّ الفلاتر: ما اختاره المستخدم صراحةً فوق
  // الافتراضي. الترتيب يُحتسب لأنه يغيّر ما يراه أولاً.
  int get activeCount => [
        quick != _QuickFilter.all,
        sort != OfferSort.newest,
        minPrice != null,
        maxPrice != null,
        dosageForm != null,
      ].where((e) => e).length;

  _OfferFilters copyWith({
    _QuickFilter? quick,
    OfferSort? sort,
    double? minPrice,
    double? maxPrice,
    DosageForm? dosageForm,
    bool clearPrices = false,
    bool clearDosage = false,
  }) =>
      _OfferFilters(
        quick: quick ?? this.quick,
        sort: sort ?? this.sort,
        minPrice: clearPrices ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrices ? null : (maxPrice ?? this.maxPrice),
        dosageForm: clearDosage ? null : (dosageForm ?? this.dosageForm),
      );
}

// عروض المستودعات المتاحة للصيدلية (Figma: الصيدلي / العروض).
// البحث والتصفية والترتيب تجري في الخادم — ليست تنقية لما وصل فقط، فالقائمة
// مُرقَّمة وما لم يصل لا يمكن البحث فيه محلياً.
class PhOffersPage extends ConsumerStatefulWidget {
  const PhOffersPage({super.key});

  @override
  ConsumerState<PhOffersPage> createState() => _PhOffersPageState();
}

class _PhOffersPageState extends ConsumerState<PhOffersPage> {
  List<SalesOfferSummary>? _offers;
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _search = '';
  Timer? _debounce;
  _OfferFilters _filters = const _OfferFilters();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await ref.read(salesOfferRepositoryProvider).getAvailableOffers(
            search: _search.isEmpty ? null : _search,
            hasBonus: switch (_filters.quick) {
              _QuickFilter.itemBonus || _QuickFilter.offerBonus => true,
              _ => null,
            },
            expiringWithinDays: _filters.quick == _QuickFilter.expiring ? 7 : null,
            minUnitPrice: _filters.minPrice,
            maxUnitPrice: _filters.maxPrice,
            dosageForm: _filters.dosageForm,
            sort: _filters.sort,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _offers = _narrowBonusKind(offers);
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

  // الخادم يعرف بونصاً واحداً يجمع المستويين، والتمييز بين «بونص أصناف»
  // و«بونص عرض كامل» يتم هنا من حقلَي الملخّص.
  List<SalesOfferSummary> _narrowBonusKind(List<SalesOfferSummary> offers) =>
      switch (_filters.quick) {
        _QuickFilter.itemBonus => offers.where((o) => o.hasItemBonus).toList(),
        _QuickFilter.offerBonus => offers.where((o) => o.hasOfferBonus).toList(),
        _ => offers,
      };

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // نصف ثانية: كتابة اسم دواء عربي لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_search.isEmpty) return;
    setState(() => _search = '');
    _load();
  }

  Future<void> _setQuick(_QuickFilter q) async {
    if (_filters.quick == q) return;
    setState(() => _filters = _filters.copyWith(quick: q));
    await _load();
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<OfferSort>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('ترتيب العروض', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final s in OfferSort.values)
              ListTile(
                title: Text(s.label),
                trailing: _filters.sort == s
                    ? Icon(Icons.check, color: context.colors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (picked == null || picked == _filters.sort) return;
    setState(() => _filters = _filters.copyWith(sort: picked));
    await _load();
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_OfferFilters>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result == null) return;
    setState(() => _filters = result);
    await _load();
  }

  // شاشة كاملة لا ورقة سفلية: من التفاصيل تُنشأ الطلبية باختيار الأصناف
  // والكميات، وذلك أكبر من أن يُحشر في ورقة.
  void _openDetails(SalesOfferSummary offer) =>
      context.push(TRoutes.phOfferDetail(offer.id));

  // الماسح حقيقي (mobile_scanner): يُعيد الرمز نصاً فنمرّره إلى البحث
  // نفسه — الباركود مجرّد طريقة أسرع لكتابة ما يُبحث عنه.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _searchController.text = code;
    _onSearchChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _OffersTopBar(
        activeFilters: _filters.activeCount,
        onFiltersTap: _openFilterSheet,
        onCatalogTap: () => context.push(TRoutes.phMedicineSearch),
        // المستودعات انتقلت إلى هنا من الرئيسية: مكانها الطبيعي حيث
        // يتصفّح الصيدلي ما يُعرَض عليه، لا بطاقة عدّاد في الرئيسية.
        onWarehousesTap: () => context.push(TRoutes.phWarehouses),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final tk = context.tokens;
    final offers = _offers ?? const <SalesOfferSummary>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
          // نفس الحقل حرفياً كما في الرئيسية (Figma: شريط بحث) — أيقونة
          // البحث في بداية القراءة وقارئ الباركود في الطرف المقابل.
          // الخادم يطابق عنوان العرض ووصفه وأسماء أصنافه، فالحقل واحد
          // يبحث عن دواء أو عن عرض.
          child: AppSearchBar(
            controller: _searchController,
            hint: 'ابحث عن دواء أو عرض…',
            onChanged: _onSearchChanged,
            onScanTap: _scanBarcode,
            onClearTap: _clearSearch,
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: _QuickFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final q = _QuickFilter.values[i];
              return AppFilterChip(
                label: q.label,
                selected: _filters.quick == q,
                onTap: () => _setQuick(q),
              );
            },
          ),
        ),

        // سطر النتائج والترتيب (Figma: النتائج والترتيب)
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _loading
                      ? 'جارٍ التحميل…'
                      : '${offers.length} ${offers.length == 1 ? 'عرض متاح' : 'عرضاً متاحاً'} لتغطيتك',
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ),
              InkWell(
                onTap: _openSortSheet,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_filters.sort.label,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.primary)),
                    const SizedBox(width: 2),
                    AppIcon(AppIcons.chevronDown,
                        size: 14, color: context.colors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(child: _buildList(offers)),
      ],
    );
  }

  Widget _buildList(List<SalesOfferSummary> offers) {
    if (_loading) return const AppListSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    if (offers.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.sell_outlined,
            message: _search.isNotEmpty || _filters.activeCount > 0
                ? 'لا عرض يطابق بحثك — جرّب توسيع الفلاتر'
                : 'لا عروض تغطّي منطقتك حالياً',
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
      itemCount: offers.length,
      // التعليقات انتقلت إلى شاشة التفاصيل — الضغط المطوّل إيماءة مخفية
      // لا يكتشفها أحد، وزرٌّ في الشريط العلوي هناك يفعل الشيء نفسه ظاهراً.
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: OfferSummaryCard(
          offer: offers[i],
          onAdd: () => _openDetails(offers[i]),
          onDetails: () => _openDetails(offers[i]),
        ),
      ),
    );
  }
}

// شريط شاشة العروض (Figma: رأس الشاشة) — عنوان، زرّ «الكتالوج»، وزرّ
// الفلاتر بشارة عدد. ليس InnerTopBar لأن هذه تبويب لا شاشة داخلية: لا رجوع.
class _OffersTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _OffersTopBar({
    required this.activeFilters,
    required this.onFiltersTap,
    required this.onCatalogTap,
    required this.onWarehousesTap,
  });

  final int activeFilters;
  final VoidCallback onFiltersTap;
  final VoidCallback onCatalogTap;
  final VoidCallback onWarehousesTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text('العروض', style: context.text.headlineSmall)),
            // زر الكتالوج: حدّ بلون العلامة ونصّ أخضر — ثانوي لا رئيسي.
            Material(
              color: Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: cs.primary)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onCatalogTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('الكتالوج',
                          style: context.text.bodySmall
                              ?.copyWith(color: cs.primary)),
                      const SizedBox(width: 6),
                      AppIcon(AppIcons.pill, size: 15, color: cs.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleIconButton(
              icon: AppIcons.warehouse,
              tooltip: 'المستودعات المتاحة',
              bordered: true,
              size: 18,
              onTap: onWarehousesTap,
            ),
            const SizedBox(width: AppSpacing.sm),
            // الشارة تخرج عن حدود الزر، فـ clipBehavior لا بدّ أن يسمح بذلك
            // وإلا قُصَّت — وهو ما حدث في نسخة سابقة.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: cs.surface,
                  shape: CircleBorder(side: BorderSide(color: cs.outline)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onFiltersTap,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AppIcon(AppIcons.sliders,
                            size: 18, color: cs.onSurface),
                      ),
                    ),
                  ),
                ),
                if (activeFilters > 0)
                  PositionedDirectional(
                    end: -4,
                    top: -4,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                      child: Text('$activeFilters',
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall
                              ?.copyWith(color: cs.onPrimary, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── ورقة التصفية المتقدّمة ───────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _OfferFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _OfferFilters _draft = widget.initial;
  late final _min = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '');
  late final _max = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final minV = double.tryParse(_min.text.trim());
    final maxV = double.tryParse(_max.text.trim());
    if (minV != null && maxV != null && minV > maxV) {
      AppSnackbar.error(context, 'الحد الأدنى أكبر من الحد الأعلى');
      return;
    }
    Navigator.pop(
      context,
      _OfferFilters(
        quick: _draft.quick,
        sort: _draft.sort,
        minPrice: minV,
        maxPrice: maxV,
        dosageForm: _draft.dosageForm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.x3l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                    child: Text('تصفية العروض', style: context.text.titleLarge)),
                TextButton(
                  onPressed: () => setState(() {
                    _draft = const _OfferFilters();
                    _min.clear();
                    _max.clear();
                  }),
                  child: const Text('مسح الكل'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            Text('الترتيب', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in OfferSort.values)
                  AppFilterChip(
                    label: s.label,
                    selected: _draft.sort == s,
                    onTap: () => setState(() => _draft = _draft.copyWith(sort: s)),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('البونص والمهلة', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final q in _QuickFilter.values)
                  AppFilterChip(
                    label: q.label,
                    selected: _draft.quick == q,
                    onTap: () => setState(() => _draft = _draft.copyWith(quick: q)),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('سعر الوحدة', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _min,
                    label: 'من',
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _max,
                    label: 'إلى',
                    hint: 'بلا حد',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('الشكل الصيدلاني', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppFilterChip(
                  label: 'الكل',
                  selected: _draft.dosageForm == null,
                  onTap: () =>
                      setState(() => _draft = _draft.copyWith(clearDosage: true)),
                ),
                for (final d in DosageForm.values)
                  AppFilterChip(
                    label: d.label,
                    selected: _draft.dosageForm == d,
                    onTap: () =>
                        setState(() => _draft = _draft.copyWith(dosageForm: d)),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              'التصفية تجري في الخادم على كل العروض التي تغطّي منطقتك، لا على '
              'ما ظهر في القائمة فقط.',
              style: context.text.labelSmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'تطبيق', onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
