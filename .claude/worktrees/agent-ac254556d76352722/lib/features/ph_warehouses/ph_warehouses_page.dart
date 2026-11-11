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

  // البحث محلي: الخادم يُرجع قائمة مختصرة بلا ترقيم، فرحلة شبكة لكل حرف
  // لا تشتري شيئاً هنا.
  List<WarehousePicker> get _filtered {
    final all = _items ?? const <WarehousePicker>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((w) =>
            w.name.toLowerCase().contains(q) ||
            w.code.toLowerCase().contains(q) ||
            w.city.toLowerCase().contains(q) ||
            w.governorate.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'المستودعات'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final shown = _filtered;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.x3l),
      children: [
        Text(
          'المستودعات النشطة التي تخدم مدينتك — منها تختار عند إنشاء طلبية توريد.',
          style: context.text.bodySmall?.copyWith(color: tk.hint),
        ),
        const SizedBox(height: AppSpacing.md),

        AppSearchBar(
          hint: 'ابحث باسم المستودع أو الكود أو المدينة',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.md),

        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3l),
            child: EmptyState(
              icon: Icons.storefront_outlined,
              message: _query.isEmpty
                  ? 'لا مستودعات نشطة تخدم مدينتك حالياً'
                  : 'لا مستودع يطابق بحثك',
            ),
          )
        else ...[
          for (final w in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _WarehouseCard(warehouse: w),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'مستودع لم يحدّد مدن خدمته يُعدّ خادماً للجميع فيظهر هنا أيضاً.',
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
        ],
      ],
    );
  }
}

// بطاقة المستودع (Figma): الاسم وسطر المدينة وعدد مدن الخدمة، شارة
// «يخدم مدينتك»، وتذييل فيه الهاتف ورابط الملف.
class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse});
  final WarehousePicker warehouse;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final w = warehouse;

    // «يخدم ٧ مدن» لا تُقال لمستودع بلا مدن محدَّدة — له نصّه الخاص.
    final coverage = w.servesAllAreas
        ? 'يخدم كل المناطق'
        : 'يخدم ${w.serviceAreaCount} ${w.serviceAreaCount == 1 ? 'مدينة' : 'مدن'}';

    return AppCard(
      onTap: () => context.push(TRoutes.phWarehouseProfile(w.id)),
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
                    Text(w.name,
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${w.city} · $coverage',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (!w.servesAllAreas)
                const StatusBadge(label: 'يخدم مدينتك', tone: StatusTone.success)
              else
                const StatusBadge(label: 'يخدم الجميع', tone: StatusTone.neutral),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // الكود لا الهاتف: القائمة متصفَّحة لكل صيدلية، وبثّ أرقام
              // المستودعات فيها نشرٌ لبيانات اتصال بلا داعٍ. الرقم يبقى
              // في ملف المستودع حيث يُقصد التواصل.
              Text(w.code,
                  style: context.text.bodySmall?.copyWith(color: tk.hint)),
              const Spacer(),
              Text('ملف المستودع وعروضه',
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
