import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// الحالات الجارية: من بانتظار الموافقة إلى جاري الشحن (لا مكتملة ولا ملغاة).
const _activeStatuses = {
  SupplyOrderStatus.pending,
  SupplyOrderStatus.confirmed,
  SupplyOrderStatus.processing,
  SupplyOrderStatus.shipped,
};

class PhHomePage extends ConsumerStatefulWidget {
  const PhHomePage({super.key});

  @override
  ConsumerState<PhHomePage> createState() => _PhHomePageState();
}

class _PhHomePageState extends ConsumerState<PhHomePage> {
  List<SupplyOrderSummary> _activeOrders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await ref
          .read(supplyOrderRepositoryProvider)
          .getMyOrders(limit: 100);
      if (!mounted) return;
      setState(() {
        _activeOrders =
            orders.where((o) => _activeStatuses.contains(o.status)).toList();
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

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 17) return 'طاب يومك،';
    return 'مساء الخير،';
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
        actions: [
          CircleIconButton(
            icon: AppIcons.search,
            tooltip: 'بحث الأسعار',
            onTap: () => context.push(TRoutes.phPriceSearch),
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
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: _QuickActionsGrid(
            onNewOrder: () => context.push(TRoutes.phWarehouses),
            onNewTender: () => context.push(TRoutes.phCreateTender),
            onReports: () => context.push(TRoutes.phReports),
            onTenderReports: () => context.push(TRoutes.phTenderReports),
          ),
        ),

        const SizedBox(height: AppSpacing.x2l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: AppSectionHeader(
            title: 'الطلبيات الجارية',
            trailing: _SeeAllLink(
              onTap: () => context.go(TRoutes.phOrders),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_activeOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              message: 'لا طلبيات جارية حالياً',
            ),
          )
        else
          for (final order in _activeOrders)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 0, AppSpacing.page, AppSpacing.md),
              child: OrderCard(
                title: 'طلب ${order.orderNumber}',
                subtitle: '${order.warehouseName} — ${order.warehouseCity}',
                metaText: '${order.itemCount} صنف',
                price: order.totalAmount != null
                    ? '${order.totalAmount!.toStringAsFixed(2)} ل.س'
                    : '—',
                statusLabel: order.status.label,
                statusTone: _statusTone(order.status),
                onDetails: () =>
                    context.push(TRoutes.phOrderDetail(order.id)),
              ),
            ),
      ],
    );
  }

  static StatusTone _statusTone(SupplyOrderStatus s) => switch (s) {
        SupplyOrderStatus.pending => StatusTone.warning,
        SupplyOrderStatus.confirmed => StatusTone.info,
        SupplyOrderStatus.processing => StatusTone.brand,
        SupplyOrderStatus.shipped => StatusTone.success,
        _ => StatusTone.neutral,
      };
}

// شبكة الإجراءات السريعة (٢×٢): طلبية جديدة · طلب تسعير · بحث أسعار · عروض.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onNewOrder,
    required this.onNewTender,
    required this.onReports,
    required this.onTenderReports,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onNewTender;
  final VoidCallback onReports;
  final VoidCallback onTenderReports;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.4,
      children: [
        _ActionTile(
          icon: AppIcons.package,
          label: 'طلبية جديدة',
          onTap: onNewOrder,
        ),
        _ActionTile(
          icon: AppIcons.fileText,
          label: 'طلب تسعير جديد',
          onTap: onNewTender,
        ),
        _ActionTile(
          icon: AppIcons.clipboardList,
          label: 'تقرير مشترياتي',
          onTap: onReports,
        ),
        _ActionTile(
          icon: AppIcons.tag,
          label: 'تقرير طلبات التسعير',
          onTap: onTenderReports,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outline),
            boxShadow: t.cardShadow,
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
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AppIcon(icon, size: 16, color: cs.onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// رابط «عرض الكل ›» في ترويسة القسم.
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
