import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/barcode_scanner_page.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// الفلاتر السريعة في الرئيسية (Figma: فلاتر سريعة).
// «الأقرب لتغطيتي» ترتيب محلّي لا معامل خادم: الخادم يفلتر أصلاً بما يغطّي
// الصيدلية، وهذه الشريحة تُقدّم ما يستهدف مدينتها بالاسم على ما يستهدف
// محافظتها عموماً.
enum _HomeFilter {
  all('الكل'),
  bonus('عروض البونص'),
  newest('الأحدث'),
  nearest('الأقرب لتغطيتي');

  const _HomeFilter(this.label);
  final String label;
}

class PhHomePage extends ConsumerStatefulWidget {
  const PhHomePage({super.key});

  @override
  ConsumerState<PhHomePage> createState() => _PhHomePageState();
}

class _PhHomePageState extends ConsumerState<PhHomePage> {
  List<SalesOfferSummary> _offers = const [];
  SupplyOrderSummary? _activeOrder;

  bool _loading = true;
  String? _error;
  _HomeFilter _filter = _HomeFilter.all;

  final _searchController = TextEditingController();
  String _search = '';
  Timer? _debounce;

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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // نصف ثانية: كتابة اسم دواء عربي لا تستحق رحلة شبكة لكل حرف.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _search = value.trim());
      try {
        await _loadOffers();
      } catch (e) {
        if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_loadOffers(), _loadActiveOrder()]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _loadOffers() async {
    final offers = await ref.read(salesOfferRepositoryProvider).getAvailableOffers(
          search: _search.isEmpty ? null : _search,
          hasBonus: _filter == _HomeFilter.bonus ? true : null,
          // البحث يستحق قائمةً أطول من «عروض مختارة لك» المختصرة.
          limit: _search.isEmpty ? 10 : 30,
        );
    if (!mounted) return;
    setState(() => _offers = _applyLocalOrder(offers));
  }

  // الرئيسية تعرض تنبيه الطلبية الجارية فقط — لا عدّادات. فشل هذا النداء
  // يترك التنبيه غائباً والشاشة تعمل، بينما فشل العروض وحده هو الخطأ
  // الجدير بالعرض.
  Future<void> _loadActiveOrder() async {
    final orders = await ref
        .read(supplyOrderRepositoryProvider)
        .getMyOrders(limit: 50)
        .then<List<SupplyOrderSummary>?>((v) => v, onError: (_) => null);
    if (!mounted || orders == null) return;

    setState(() {
      // التنبيه يتتبّع أقرب طلبية فعلاً في الطريق، لا أي طلبية جارية.
      _activeOrder = orders
          .where((o) =>
              o.status == SupplyOrderStatus.shipped ||
              o.status == SupplyOrderStatus.processing ||
              o.status == SupplyOrderStatus.confirmed)
          .firstOrNull;
    });
  }

  List<SalesOfferSummary> _applyLocalOrder(List<SalesOfferSummary> offers) {
    if (_filter != _HomeFilter.nearest) return offers;
    final me = ref.read(pharmacyMeProvider).value;
    if (me == null || me.city.isEmpty) return offers;
    final sorted = [...offers];
    sorted.sort((a, b) {
      int rank(SalesOfferSummary o) =>
          o.targetRegions.any((r) => r.city == me.city) ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });
    return sorted;
  }

  Future<void> _setFilter(_HomeFilter f) async {
    if (_filter == f) return;
    setState(() => _filter = f);
    try {
      await _loadOffers();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  // شاشة كاملة: من التفاصيل تُنشأ الطلبية باختيار الأصناف والكميات.
  void _openOffer(SalesOfferSummary offer) =>
      context.push(TRoutes.phOfferDetail(offer.id));

  // «قارن الأسعار»: نفس كلمة البحث تُمرَّر إلى شاشة البحث المقارن، حيث
  // تُعرض أسعار كل المستودعات لهذا الدواء — عروضاً وتسعيراً مباشراً.
  void _openPriceSearch([String? query]) {
    final q = (query ?? _searchController.text).trim();
    context.push(
      q.isEmpty
          ? TRoutes.phPriceSearch
          : '${TRoutes.phPriceSearch}?q=${Uri.encodeComponent(q)}',
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 17) return 'طاب يومك،';
    return 'مساء الخير،';
  }

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
    final me = ref.watch(pharmacyMeProvider);
    final unread = ref.watch(phUnreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: WelcomeTopBar(
        greeting: _greeting(),
        name: me.value?.pharmacyName ?? 'صيدليتي',
        hasUnread: unread > 0,
        onNotificationsTap: () => context.push(TRoutes.phNotifications),
        // بحث الأسعار والسلّة يعيشان عبر الشاشات، فمدخلهما الشريط العلوي
        // لا بطاقات وصول سريع تزاحم العروض.
        actions: [
          CircleIconButton(
            icon: AppIcons.search,
            tooltip: 'بحث الأسعار',
            onTap: () => _openPriceSearch(''),
          ),
          CartButton(
            count: ref.watch(cartCountProvider),
            onTap: () => context.push(TRoutes.phCart),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3l),
      children: [
        if (_activeOrder != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: _OrderAlert(
              order: _activeOrder!,
              onTap: () => context.go(TRoutes.phOrders),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          // البحث هنا داخل العروض لا في الكتالوج العام: الصيدلي في الرئيسية
          // يسأل «من يعرض هذا الدواء؟» لا «ما هذا الدواء؟». الخادم يطابق
          // عنوان العرض ووصفه وأسماء أصنافه، فالحقل يجد الدواء والعرض معاً.
          child: AppSearchBar(
            controller: _searchController,
            hint: 'ابحث عن دواء داخل العروض…',
            onChanged: _onSearchChanged,
            // الإرسال ينقل البحث نفسه إلى «بحث الأسعار»: الرئيسية تبحث داخل
            // العروض، وهناك تُقارَن أسعار المستودعات كلها لنفس الدواء.
            onSubmitted: _openPriceSearch,
            onScanTap: _scanBarcode,
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: _HomeFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final f = _HomeFilter.values[i];
              return AppFilterChip(
                label: f.label,
                selected: _filter == f,
                onTap: () => _setFilter(f),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: AppSectionHeader(
            title: _search.isEmpty
                ? 'عروض مختارة لك'
                : 'نتائج البحث (${_offers.length})',
            // أثناء البحث يصير الرابط مدخلاً إلى مقارنة الأسعار: من يبحث عن
            // دواء بعينه يريد أرخص مصدر له، لا قائمة العروض كاملةً.
            trailing: _search.isEmpty
                ? _SeeAllLink(
                    label: 'عرض الكل',
                    onTap: () => context.go(TRoutes.phOffers),
                  )
                : _SeeAllLink(label: 'قارن الأسعار', onTap: _openPriceSearch),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_offers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.sell_outlined,
              message: _search.isEmpty
                  ? 'لا عروض تغطّي منطقتك حالياً'
                  : 'لا عرض يتضمّن «$_search» ضمن ما يغطّي منطقتك',
            ),
          )
        else
          for (final offer in _offers)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
              child: OfferSummaryCard(
                offer: offer,
                onDetails: () => _openOffer(offer),
              ),
            ),

      ],
    );
  }
}

// تنبيه الطلبية الجارية (Figma: تنبيه طلب) — سطح العلامة الباهت، أيقونة
// شاحنة دائرية في الطرف، وسهم يقود إلى مسار الطلبية.
class _OrderAlert extends StatelessWidget {
  const _OrderAlert({required this.order, required this.onTap});

  final SupplyOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;

    return Material(
      color: t.brandSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Center(
                  child: AppIcon(AppIcons.truck, size: 18, color: cs.onPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلبك ${order.orderNumber} ${order.status.label}',
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('اضغط لتتبع مراحل التسليم',
                        style: context.text.bodySmall?.copyWith(color: t.hint)),
                  ],
                ),
              ),
              AppIcon(AppIcons.chevronForwardRtl, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// رابط «عرض الكل ›» في ترويسة القسم.
class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.onTap, this.label = 'عرض الكل'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: context.text.bodySmall?.copyWith(color: cs.primary)),
          const SizedBox(width: 2),
          AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
        ],
      ),
    );
  }
}

