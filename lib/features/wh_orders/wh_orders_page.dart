import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

Color _statusColor(SupplyOrderStatus s) => switch (s) {
      SupplyOrderStatus.pending => TawridColors.statusPending,
      SupplyOrderStatus.confirmed => TawridColors.statusAccepted,
      SupplyOrderStatus.processing => TawridColors.statusProcessing,
      SupplyOrderStatus.shipped => TawridColors.statusReady,
      SupplyOrderStatus.delivered => TawridColors.statusDelivering,
      SupplyOrderStatus.completed => TawridColors.statusCompleted,
      SupplyOrderStatus.cancelled => TawridColors.statusCancelled,
    };

// الطلبيات الواردة من الصيدليات — قائمة فعلية (بدل الحالة الفارغة الثابتة
// سابقاً) مع زر تحديث وسحب للتحديث، وإمكانية تحديث حالة الطلبية من بطاقتها.
class WhOrdersPage extends ConsumerStatefulWidget {
  const WhOrdersPage({super.key});

  @override
  ConsumerState<WhOrdersPage> createState() => _WhOrdersPageState();
}

class _WhOrdersPageState extends ConsumerState<WhOrdersPage> {
  List<SupplyOrderSummary>? _orders;
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
      final list = await ref.read(supplyOrderRepositoryProvider).getWarehouseOrders();
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _openDetails(SupplyOrderSummary order) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OrderDetailSheet(orderId: order.id, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبيات الواردة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'تحديث', onPressed: _loading ? null : _load),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final orders = _orders ?? [];
    if (orders.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(message: 'لا توجد طلبيات واردة بعد', icon: Icons.inbox_outlined),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final color = _statusColor(order.status);
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: TawridColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TawridColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openDetails(order),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('طلبية ${order.orderNumber}',
                                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                            Icon(Icons.chevron_left, size: 18, color: TawridColors.hint),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 5),
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            Text('${order.status.label} · ${order.itemCount} صنف · ${formatSmartTimestamp(order.createdOn)}',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: TawridColors.hint)),
                          ],
                        ),
                        if (order.invoiceCreated) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text('تم إصدار فاتورة لهذه الطلبية',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: TawridColors.success)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderDetailSheet extends ConsumerStatefulWidget {
  const _OrderDetailSheet({required this.orderId, required this.onChanged});
  final String orderId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends ConsumerState<_OrderDetailSheet> {
  SupplyOrderDetail? _order;
  bool _loading = true;
  bool _updating = false;
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
      final order = await ref.read(supplyOrderRepositoryProvider).getWarehouseOrderById(widget.orderId);
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(SupplyOrderStatus next) async {
    setState(() => _updating = true);
    try {
      await ref.read(supplyOrderRepositoryProvider).updateOrderStatus(widget.orderId, next);
      widget.onChanged();
      if (mounted) {
        AppSnackbar.success(context, 'تم تحديث حالة الطلبية إلى ${next.label}');
        await _load();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_loading) {
          return const SafeArea(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingState()));
        }
        if (_error != null) {
          return SafeArea(
            child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: ErrorState(message: _error!, onRetry: _load)),
          );
        }
        final order = _order!;
        final nextOptions = order.status.nextAllowed;

        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('طلبية ${order.orderNumber}',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 4),
              Text(formatSmartTimestamp(order.createdOn),
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.hint)),
              const SizedBox(height: AppSpacing.md),
              Text('الحالة: ${order.status.label}',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, color: _statusColor(order.status))),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(order.notes!, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5)),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              Text('الأصناف (${order.items.length})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('${item.medicineName} — ${item.quantity} ${item.unit}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5)),
                ),
              if (nextOptions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text('تحديث الحالة', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: nextOptions
                      .map((s) => FilledButton.tonal(
                            onPressed: _updating ? null : () => _updateStatus(s),
                            child: Text(s.label),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
