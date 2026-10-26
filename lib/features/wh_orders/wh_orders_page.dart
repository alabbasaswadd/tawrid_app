import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/features/wh_home/wh_home_page.dart' show WhOrderCard;
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// نغمة شارة حالة الطلبية عند المستودع — مشتركة مع الرئيسية والتفاصيل.
StatusTone whOrderTone(SupplyOrderStatus s) => switch (s) {
      SupplyOrderStatus.pending => StatusTone.warning,
      SupplyOrderStatus.confirmed => StatusTone.brand,
      SupplyOrderStatus.processing => StatusTone.brand,
      SupplyOrderStatus.shipped => StatusTone.info,
      SupplyOrderStatus.delivered => StatusTone.info,
      SupplyOrderStatus.completed => StatusTone.success,
      SupplyOrderStatus.cancelled => StatusTone.danger,
    };

// تبويبات الطلبات الواردة (Figma): الجديدة، المؤكدة، قيد التجهيز، المكتملة.
//
// «المكتملة» تضم كل ما خرج من دورة العمل — مشحونة ومسلَّمة ومكتملة وملغاة:
// بعدها لا يبقى على المستودع إجراء، والتفريق بينها يخصّ السجلّ لا القائمة.
enum _WhOrdersTab {
  isNew('الجديدة'),
  confirmed('المؤكدة'),
  processing('قيد التجهيز'),
  done('المكتملة');

  const _WhOrdersTab(this.label);
  final String label;

  bool matches(SupplyOrderStatus s) => switch (this) {
        _WhOrdersTab.isNew => s == SupplyOrderStatus.pending,
        _WhOrdersTab.confirmed => s == SupplyOrderStatus.confirmed,
        _WhOrdersTab.processing => s == SupplyOrderStatus.processing,
        _WhOrdersTab.done => s == SupplyOrderStatus.shipped ||
            s == SupplyOrderStatus.delivered ||
            s == SupplyOrderStatus.completed ||
            s == SupplyOrderStatus.cancelled,
      };

  String countLabel(int n) => switch (this) {
        _WhOrdersTab.isNew =>
          '$n ${n == 1 ? 'طلب جديد' : 'طلبات جديدة'} بانتظار قرارك',
        _WhOrdersTab.confirmed => '$n ${n == 1 ? 'طلب مؤكَّد' : 'طلبات مؤكَّدة'}',
        _WhOrdersTab.processing => '$n ${n == 1 ? 'طلب' : 'طلبات'} قيد التجهيز',
        _WhOrdersTab.done => '$n ${n == 1 ? 'طلب منتهٍ' : 'طلبات منتهية'}',
      };

  String get emptyMessage => switch (this) {
        _WhOrdersTab.isNew => 'لا طلبات جديدة بانتظار قرارك',
        _WhOrdersTab.confirmed => 'لا طلبات مؤكَّدة حالياً',
        _WhOrdersTab.processing => 'لا طلبات قيد التجهيز',
        _WhOrdersTab.done => 'لا طلبات منتهية بعد',
      };
}

// الطلبات الواردة للمستودع (Figma: المستودع / الطلبات).
class WhOrdersPage extends ConsumerStatefulWidget {
  const WhOrdersPage({super.key});

  @override
  ConsumerState<WhOrdersPage> createState() => _WhOrdersPageState();
}

class _WhOrdersPageState extends ConsumerState<WhOrdersPage> {
  List<SupplyOrderSummary>? _orders;
  bool _loading = true;
  String? _error;
  _WhOrdersTab _tab = _WhOrdersTab.isNew;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] يُحدّث بلا مؤشّر تحميل — عند العودة من التفاصيل.
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(supplyOrderRepositoryProvider)
          .getWarehouseOrders(limit: 50);
      if (!mounted) return;
      setState(() {
        _orders = list;
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

  Future<void> _openDetails(SupplyOrderSummary order) async {
    await context.push(TRoutes.whOrderDetail(order.id));
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات الواردة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _orders ?? const <SupplyOrderSummary>[];
    final shown = all.where((o) => _tab.matches(o.status)).toList();
    final tk = context.tokens;

    return Column(
      children: [
        // الشرائح أفقية: أربع شرائح عربية لا تتّسع لعرض الشاشة في صفّ ثابت.
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: _WhOrdersTab.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final t = _WhOrdersTab.values[i];
              return AppFilterChip(
                label: t.label,
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(_tab.countLabel(shown.length),
                style: context.text.bodySmall?.copyWith(color: tk.hint)),
          ),
        ),

        Expanded(
          child: shown.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.inbox_outlined,
                      message: _tab.emptyMessage,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => WhOrderCard(
                    order: shown[i],
                    onTap: () => _openDetails(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
