import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/repositories/warehouse_profile_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

import 'package:tawrid_app/features/wh_orders/wh_orders_page.dart' show whOrderTone;

// الصفحة الرئيسية للمستودع (Figma: المستودع / الرئيسية).
//
// لوحة عمل لا فيد: أربعة عدّادات تقول ما ينتظر قراراً، تنبيه للعروض
// المقاربة على الانتهاء، إجراء رئيسي واحد (إنشاء عرض)، ثم الطلبات
// الجديدة — وهي ما يُفتح التطبيق لأجله صباحاً.
class WhHomePage extends ConsumerStatefulWidget {
  const WhHomePage({super.key});

  @override
  ConsumerState<WhHomePage> createState() => _WhHomePageState();
}

class _WhHomePageState extends ConsumerState<WhHomePage> {
  List<SupplyOrderSummary> _orders = const [];
  List<SalesOfferSummary> _offers = const [];
  List<TenderSummary> _openRequests = const [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      // الطلبات هي جوهر الشاشة، فهي وحدها التي يُسقط فشلها الصفحة.
      final orders = await ref
          .read(supplyOrderRepositoryProvider)
          .getWarehouseOrders(limit: 50);

      // العدّادات الجانبية تتحمّل الفشل: عدّادٌ صفر أهون من شاشة خطأ.
      List<SalesOfferSummary> offers;
      try {
        offers = await ref.read(salesOfferRepositoryProvider).getMyOffers(limit: 50);
      } catch (_) {
        offers = const [];
      }

      List<TenderSummary> requests;
      try {
        requests =
            await ref.read(tenderRepositoryProvider).getOpenTenders(limit: 50);
      } catch (_) {
        requests = const [];
      }

      if (!mounted) return;
      setState(() {
        _orders = orders;
        _offers = offers;
        _openRequests = requests;
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

  int get _newOrders =>
      _orders.where((o) => o.status == SupplyOrderStatus.pending).length;

  int get _processing => _orders
      .where((o) =>
          o.status == SupplyOrderStatus.confirmed ||
          o.status == SupplyOrderStatus.processing)
      .length;

  List<SalesOfferSummary> get _activeOffers =>
      _offers.where((o) => o.status == SalesOfferStatus.active).toList();

  // «يقارب على الانتهاء» = ثلاثة أيام أو أقل، نفس عتبة بطاقة العرض.
  List<SalesOfferSummary> get _expiringOffers => _activeOffers
      .where((o) {
        final days = o.expiresAt.difference(DateTime.now()).inDays;
        return days >= 0 && days <= 3;
      })
      .toList();

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 17) return 'طاب يومك،';
    return 'مساء الخير،';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(warehouseMeProvider).value;
    final unread = ref.watch(whUnreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: WelcomeTopBar(
        greeting: _greeting(),
        name: me == null
            ? 'مستودعي'
            : me.city.isEmpty
                ? me.warehouseName
                : '${me.warehouseName} — ${me.city}',
        hasUnread: unread > 0,
        onNotificationsTap: () => context.push(TRoutes.whNotifications),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final newOrders =
        _orders.where((o) => o.status == SupplyOrderStatus.pending).toList();
    final expiring = _expiringOffers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        // شبكة العدّادات ٢×٢ (Figma) — أرقام تُقرأ لمحةً وتفتح وجهتها.
        Row(
          children: [
            Expanded(
              child: SummaryCounter(
                value: '$_newOrders',
                label: 'طلبات جديدة',
                icon: AppIcons.clipboardList,
                onTap: () => context.go(TRoutes.whOrders),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SummaryCounter(
                value: '$_processing',
                label: 'قيد التجهيز',
                icon: AppIcons.clock,
                onTap: () => context.go(TRoutes.whOrders),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SummaryCounter(
                value: '${_activeOffers.length}',
                label: 'عرضاً سارياً',
                icon: AppIcons.tag,
                onTap: () => context.go(TRoutes.whOffers),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SummaryCounter(
                value: '${_openRequests.length}',
                label: 'طلبات تسعير بتغطيتي',
                icon: AppIcons.fileText,
                onTap: () => context.push(TRoutes.whTenders),
              ),
            ),
          ],
        ),

        // تنبيه العروض المقاربة على الانتهاء — يظهر حين يوجد ما ينتهي فعلاً.
        if (expiring.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ExpiryAlert(
            count: expiring.length,
            onTap: () => context.go(TRoutes.whOffers),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'إنشاء عرض جديد',
          onPressed: () async {
            await context.push(TRoutes.whCreateOffer);
            if (mounted) await _load(silent: true);
          },
        ),

        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(
          title: 'الطلبات الجديدة',
          trailing: _SeeAllLink(onTap: () => context.go(TRoutes.whOrders)),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (newOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              message: 'لا طلبات جديدة بانتظار قرارك',
            ),
          )
        else
          for (final order in newOrders.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: WhOrderCard(
                order: order,
                onTap: () async {
                  await context.push(TRoutes.whOrderDetail(order.id));
                  if (mounted) await _load(silent: true);
                },
              ),
            ),
      ],
    );
  }
}

// تنبيه العروض المقاربة على الانتهاء (Figma: سطح تحذيري ذهبي).
class _ExpiryAlert extends StatelessWidget {
  const _ExpiryAlert({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Material(
      color: tk.warningSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 22, color: tk.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'عرض يقارب' : 'عروض تقارب'} على الانتهاء',
                      style: context.text.titleSmall?.copyWith(color: tk.warning),
                    ),
                    Text('راجع العروض وجدّد مدتها قبل انتهائها',
                        style:
                            context.text.bodySmall?.copyWith(color: tk.warning)),
                  ],
                ),
              ),
              AppIcon(AppIcons.chevronForwardRtl, size: 16, color: tk.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('عرض الكل',
              style: context.text.bodySmall?.copyWith(color: cs.primary)),
          const SizedBox(width: 2),
          AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
        ],
      ),
    );
  }
}

// بطاقة الطلب الوارد (Figma: بطاقة طلب) — مشتركة بين الرئيسية وشاشة
// الطلبات، فالتصميم واحد والسلوك واحد.
class WhOrderCard extends StatelessWidget {
  const WhOrderCard({required this.order, required this.onTap, super.key});

  final SupplyOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return AppCard(
      onTap: onTap,
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
                    Text('طلب رقم ${order.orderNumber}',
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    // اسم الصيدلية ومدينتها — المستودع يعرف عملاءه بالاسم.
                    Text('${order.counterpartName} — ${order.counterpartCity}',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                  label: order.status.label, tone: whOrderTone(order.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatSmartTimestamp(order.createdOn)} · '
            '${order.itemCount} ${order.itemCount == 1 ? 'صنف' : 'أصناف'}',
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (order.totalAmount != null)
                Text(formatMoneyWith(order.totalAmount!, kPlatformCurrency),
                    style: context.priceBrandStyle)
              else
                Text('بانتظار التسعير',
                    style: context.text.bodySmall?.copyWith(color: tk.hint)),
              const Spacer(),
              Text('عرض التفاصيل',
                  style: context.text.bodySmall?.copyWith(color: cs.primary)),
              const SizedBox(width: 2),
              AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
            ],
          ),
        ],
      ),
    );
  }
}
