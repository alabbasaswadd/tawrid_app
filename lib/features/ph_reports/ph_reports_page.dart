import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

class PhReportsPage extends ConsumerStatefulWidget {
  const PhReportsPage({super.key});

  @override
  ConsumerState<PhReportsPage> createState() => _PhReportsPageState();
}

class _PhReportsPageState extends ConsumerState<PhReportsPage> {
  List<SupplyOrderSummary> _orders = const [];
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
          .getMyOrders(limit: 500);
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  _ReportStats get _stats => _ReportStats.from(_orders);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'تقرير مشترياتي'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const AppDetailSkeleton()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final s = _stats;
    if (_orders.isEmpty) {
      return const UiEmpty(
        message: 'لا طلبيات حتى الآن',
        description: 'ستظهر هنا إحصائيات مشترياتك بعد تنفيذ أول طلبية.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        // ── ملخّص رقمي ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SummaryCounter(
                value: '${s.total}',
                label: 'إجمالي الطلبيات',
                icon: AppIcons.clipboardList,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SummaryCounter(
                value: formatMoney(s.totalSpent),
                label: 'الإنفاق الكلي (ل.س)',
                icon: AppIcons.tag,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.x2l),
        AppSectionHeader(title: 'توزيع الطلبيات حسب الحالة'),
        const SizedBox(height: AppSpacing.md),

        // ── توزيع الحالات ────────────────────────────────────────────────
        for (final entry in s.byStatus.entries)
          if (entry.value > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StatusRow(
                status: entry.key,
                count: entry.value,
              ),
            ),

        if (s.topWarehouses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x2l),
          AppSectionHeader(title: 'أكثر المستودعات تعاملاً'),
          const SizedBox(height: AppSpacing.md),
          for (final wh in s.topWarehouses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _WarehouseRow(
                name: wh.name,
                city: wh.city,
                orderCount: wh.count,
                totalSpent: wh.spent,
              ),
            ),
        ],
      ],
    );
  }
}

// ── بطاقة صف حالة ─────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, required this.count});

  final SupplyOrderStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
        boxShadow: tk.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(status.label, style: context.text.bodyMedium),
          ),
          Text(
            '$count',
            style: context.text.titleMedium?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('طلبية', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

// ── بطاقة صف مستودع ───────────────────────────────────────────────────────
class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({
    required this.name,
    required this.city,
    required this.orderCount,
    required this.totalSpent,
  });

  final String name;
  final String city;
  final int orderCount;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
        boxShadow: tk.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tk.brandSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppIcon(AppIcons.warehouse, size: 18, color: cs.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.text.titleSmall),
                Text(
                  '$city · $orderCount طلبية',
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
          if (totalSpent > 0)
            Text(
              '${formatMoney(totalSpent)} ل.س',
              style: context.priceStyle,
            ),
        ],
      ),
    );
  }
}

// ── حسابات الإحصاء ────────────────────────────────────────────────────────
class _WarehouseStat {
  final String name;
  final String city;
  final int count;
  final double spent;
  const _WarehouseStat({
    required this.name,
    required this.city,
    required this.count,
    required this.spent,
  });
}

class _ReportStats {
  final int total;
  final double totalSpent;
  final Map<SupplyOrderStatus, int> byStatus;
  final List<_WarehouseStat> topWarehouses;

  const _ReportStats({
    required this.total,
    required this.totalSpent,
    required this.byStatus,
    required this.topWarehouses,
  });

  factory _ReportStats.from(List<SupplyOrderSummary> orders) {
    final byStatus = <SupplyOrderStatus, int>{};
    final whCount = <String, int>{};
    final whSpent = <String, double>{};
    final whMeta = <String, ({String name, String city})>{};
    double totalSpent = 0;

    for (final o in orders) {
      byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
      whCount[o.warehouseName] = (whCount[o.warehouseName] ?? 0) + 1;
      whMeta[o.warehouseName] = (name: o.warehouseName, city: o.warehouseCity);
      if (o.status == SupplyOrderStatus.completed ||
          o.status == SupplyOrderStatus.delivered) {
        final amount = o.totalAmount ?? 0;
        whSpent[o.warehouseName] = (whSpent[o.warehouseName] ?? 0) + amount;
        totalSpent += amount;
      }
    }

    final top = whCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ReportStats(
      total: orders.length,
      totalSpent: totalSpent,
      byStatus: byStatus,
      topWarehouses: top.take(5).map((e) {
        final meta = whMeta[e.key]!;
        return _WarehouseStat(
          name: meta.name,
          city: meta.city,
          count: e.value,
          spent: whSpent[e.key] ?? 0,
        );
      }).toList(),
    );
  }
}
