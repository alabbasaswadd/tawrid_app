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

enum _WhSort { none, acceptance, delivery }

// المستودعات المتاحة للصيدلية (Figma: الصيدلي / المستودعات).
//
// القائمة مُصفّاة في الخادم بالتغطية، لكن سببَي الظهور مختلفان: مستودع أدرج
// مدينتك ضمن مدن خدمته — التزام صريح تحمله شارة «يخدم مدينتك» — ومستودع لم
// يحدّد مدناً أصلاً فيُعدّ خادماً للجميع. الحاشية أسفل القائمة تقول ذلك
// صراحةً بدل أن يحزر الصيدلي لماذا يرى مستودعاً بعيداً.
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
  _WhSort _sort = _WhSort.none;

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

  // البحث والترتيب محليان — الخادم يُرجع قائمة مختصرة بلا ترقيم.
  List<WarehousePicker> get _filtered {
    var all = _items ?? const <WarehousePicker>[];
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      all = all
          .where((w) =>
              w.name.toLowerCase().contains(q) ||
              w.code.toLowerCase().contains(q) ||
              w.city.toLowerCase().contains(q) ||
              w.governorate.toLowerCase().contains(q))
          .toList();
    }
    if (_sort == _WhSort.acceptance) {
      // المستودعات بلا بيانات تُرسل إلى النهاية.
      all = [...all]..sort((a, b) {
          if (a.avgAcceptanceDays == null && b.avgAcceptanceDays == null) return 0;
          if (a.avgAcceptanceDays == null) return 1;
          if (b.avgAcceptanceDays == null) return -1;
          return a.avgAcceptanceDays!.compareTo(b.avgAcceptanceDays!);
        });
    } else if (_sort == _WhSort.delivery) {
      all = [...all]..sort((a, b) {
          if (a.avgDeliveryDays == null && b.avgDeliveryDays == null) return 0;
          if (a.avgDeliveryDays == null) return 1;
          if (b.avgDeliveryDays == null) return -1;
          return a.avgDeliveryDays!.compareTo(b.avgDeliveryDays!);
        });
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'المستودعات', showBack: false),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
            child: AppSearchBar(
              hint: 'ابحث باسم المستودع أو الكود أو المدينة',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          _SortChips(
            current: _sort,
            onChanged: (s) => setState(() => _sort = s),
          ),
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
      return ListView(children: [
        const SizedBox(height: AppSpacing.x3l),
        UiEmpty(
          appIcon: AppIcons.warehouse,
          message: _query.isEmpty
              ? 'لا مستودعات نشطة تخدم مدينتك حالياً'
              : 'لا مستودع يطابق بحثك',
        ),
      ]);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.x3l),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _WarehouseCard(warehouse: shown[i]),
      ),
    );
  }
}

class _SortChips extends StatelessWidget {
  const _SortChips({required this.current, required this.onChanged});
  final _WhSort current;
  final ValueChanged<_WhSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          _Chip(
            label: 'الكل',
            selected: current == _WhSort.none,
            onTap: () => onChanged(_WhSort.none),
          ),
          const SizedBox(width: AppSpacing.xs),
          _Chip(
            label: 'الأسرع قبولاً',
            appIcon: AppIcons.check,
            selected: current == _WhSort.acceptance,
            onTap: () => onChanged(_WhSort.acceptance),
          ),
          const SizedBox(width: AppSpacing.xs),
          _Chip(
            label: 'الأسرع تسليماً',
            appIcon: AppIcons.truck,
            selected: current == _WhSort.delivery,
            onTap: () => onChanged(_WhSort.delivery),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.appIcon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppIcons? appIcon;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (appIcon != null) ...[
              AppIcon(appIcon!, size: 13,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse});
  final WarehousePicker warehouse;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final w = warehouse;

    final coverageText = w.servesAllAreas
        ? 'يخدم كل المناطق'
        : 'يغطي ${w.serviceAreaCount} '
            '${w.serviceAreaCount == 1 ? 'مدينة' : 'مدن'}';

    return AppCard(
      onTap: () => context.push(TRoutes.phWarehouseProfile(w.id)),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  w.name,
                  style: context.text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIcon(AppIcons.chevronForwardRtl, size: 14, color: tk.hint),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            w.city.isEmpty ? w.governorate : '${w.city}، ${w.governorate}',
            style: context.text.bodySmall?.copyWith(color: tk.hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (w.code.isNotEmpty) ...[
                Text(w.code,
                    style: context.text.labelSmall?.copyWith(color: tk.hint)),
                Text(' · ',
                    style: context.text.labelSmall?.copyWith(color: tk.hint)),
              ],
              Text(coverageText,
                  style: context.text.labelSmall?.copyWith(color: cs.primary)),
            ],
          ),
          if (w.avgAcceptanceDays != null || w.avgDeliveryDays != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (w.avgAcceptanceDays != null) ...[
                  AppIcon(AppIcons.check, size: 12, color: tk.hint),
                  const SizedBox(width: 3),
                  Text(
                    'قبول ${w.avgAcceptanceDays!.toStringAsFixed(1)} ي',
                    style: context.text.labelSmall?.copyWith(color: tk.hint),
                  ),
                ],
                if (w.avgAcceptanceDays != null && w.avgDeliveryDays != null)
                  Text('  ·  ',
                      style: context.text.labelSmall?.copyWith(color: tk.hint)),
                if (w.avgDeliveryDays != null) ...[
                  AppIcon(AppIcons.truck, size: 12, color: tk.hint),
                  const SizedBox(width: 3),
                  Text(
                    'تسليم ${w.avgDeliveryDays!.toStringAsFixed(1)} ي',
                    style: context.text.labelSmall?.copyWith(color: tk.hint),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
