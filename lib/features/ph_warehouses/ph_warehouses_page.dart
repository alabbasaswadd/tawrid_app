import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/warehouse_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

enum _SortMode { none, fastestAccept, fastestDelivery, fastestTotal }

extension _SortModeLabel on _SortMode {
  String get label => switch (this) {
        _SortMode.none => 'الافتراضي',
        _SortMode.fastestAccept => 'أسرع قبولاً',
        _SortMode.fastestDelivery => 'أسرع تسليماً',
        _SortMode.fastestTotal => 'الأسرع إجمالاً',
      };
}

class PhWarehousesPage extends ConsumerStatefulWidget {
  const PhWarehousesPage({super.key});

  @override
  ConsumerState<PhWarehousesPage> createState() => _PhWarehousesPageState();
}

class _PhWarehousesPageState extends ConsumerState<PhWarehousesPage> {
  List<WarehousePicker>? _items;
  bool _loading = true;
  String? _error;
  String _query = '';
  _SortMode _sortMode = _SortMode.none;

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
      final list = await ref.read(warehouseRepositoryProvider).getActiveWarehouses();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  List<WarehousePicker> get _filtered {
    final all = _items ?? const <WarehousePicker>[];
    final q = _query.trim().toLowerCase();
    var result = q.isEmpty
        ? all
        : all
            .where((w) =>
                w.name.toLowerCase().contains(q) ||
                w.code.toLowerCase().contains(q) ||
                w.city.toLowerCase().contains(q) ||
                w.governorate.toLowerCase().contains(q))
            .toList();

    if (_sortMode == _SortMode.none) return result;

    result = List.of(result);
    const big = 9999.0; // قيمة كبيرة للمستودعات التي لا تملك بيانات
    result.sort((a, b) {
      final double aVal;
      final double bVal;
      switch (_sortMode) {
        case _SortMode.fastestAccept:
          aVal = a.avgAcceptanceDays ?? big;
          bVal = b.avgAcceptanceDays ?? big;
        case _SortMode.fastestDelivery:
          aVal = a.avgDeliveryDays ?? big;
          bVal = b.avgDeliveryDays ?? big;
        case _SortMode.fastestTotal:
          aVal = (a.avgAcceptanceDays ?? big) + (a.avgDeliveryDays ?? big);
          bVal = (b.avgAcceptanceDays ?? big) + (b.avgDeliveryDays ?? big);
        case _SortMode.none:
          return 0;
      }
      return aVal.compareTo(bVal);
    });
    return result;
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page, vertical: AppSpacing.xs),
                child: Text('ترتيب المستودعات',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final mode in _SortMode.values)
                ListTile(
                  title: Text(mode.label),
                  trailing: _sortMode == mode
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _sortMode = mode);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستودعات'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'ترتيب',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(AppIcons.sliders, size: 22),
                if (_sortMode != _SortMode.none)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث ثابت في الأعلى
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
            child: AppSearchBar(
              hint: 'ابحث باسم المستودع أو الكود أو المدينة',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // القائمة قابلة للتمرير
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final shown = _filtered;

    if (shown.isEmpty) {
      return UiEmpty(
        appIcon: AppIcons.warehouse,
        message: _query.isEmpty
            ? 'لا مستودعات نشطة حالياً'
            : 'لا مستودع يطابق بحثك',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _WarehouseCard(warehouse: shown[i]),
      ),
    );
  }
}

// كارد المستودع — مستطيل أفقي، خلفية بيضاء، بدون أيقونة كبيرة وبدون تذييل
class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse});
  final WarehousePicker warehouse;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final w = warehouse;

    const radius = BorderRadius.all(Radius.circular(AppRadius.md));

    // نص متوسط مدة القبول/التسليم — يُظهر فقط إذا توفّر أحدهما
    final hasStats = w.avgAcceptanceDays != null || w.avgDeliveryDays != null;
    final acceptText = w.avgAcceptanceDays != null
        ? 'قبول: ${w.avgAcceptanceDays!.toStringAsFixed(1)} ي'
        : null;
    final deliveryText = w.avgDeliveryDays != null
        ? 'تسليم: ${w.avgDeliveryDays!.toStringAsFixed(1)} ي'
        : null;
    final statsText = [acceptText, deliveryText]
        .where((s) => s != null)
        .join('  |  ');

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push(TRoutes.phWarehouseProfile(w.id)),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: radius,
            border: Border.all(color: cs.outline),
            boxShadow: tk.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              // السهم في المنتصف عمودياً بفضل crossAxisAlignment.center
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        w.code,
                        style: context.text.labelSmall?.copyWith(color: tk.hint),
                      ),
                      if (w.city.isNotEmpty || w.governorate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AppIcon(AppIcons.mapPin, size: 12, color: tk.hint),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                w.city.isEmpty
                                    ? w.governorate
                                    : '${w.city}، ${w.governorate}',
                                style: context.text.bodySmall
                                    ?.copyWith(color: tk.hint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasStats) ...[
                        const SizedBox(height: 4),
                        Text(
                          statsText,
                          style: context.text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // السهم في المنتصف
                AppIcon(AppIcons.chevronForwardRtl, size: 16, color: tk.hint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
