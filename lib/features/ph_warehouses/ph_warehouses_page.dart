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

// كاتالوج المستودعات — المستودعات التي تخدم منطقتك، بطاقةً لكلٍّ منها.
//
// كانت الشاشة تفتح على قائمة أدوية مدموجة من كل المستودعات، فيبحث
// الصيدلي في سوقٍ بلا بائعين. وسؤاله الأول «من يخدمني؟» لا «ما الأصناف
// المتاحة؟» — فصارت المستودعات أولاً، وكتالوج كلٍّ منها خلف بطاقته.
//
// والتصفية بالتغطية من الخادم لا هنا: GetActiveServingPharmacyAsync
// يقرأ مناطق خدمة كل مستودع مقابل مدينة الصيدلية.
class PhWarehousesPage extends ConsumerStatefulWidget {
  const PhWarehousesPage({super.key});

  @override
  ConsumerState<PhWarehousesPage> createState() => _PhWarehousesPageState();
}

class _PhWarehousesPageState extends ConsumerState<PhWarehousesPage> {
  List<WarehousePicker> _warehouses = const [];
  bool _loading = true;
  ApiException? _error;

  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(warehouseRepositoryProvider)
          .getActiveWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e);
        _loading = false;
      });
    }
  }

  /// التصفية محلّية: القائمة قصيرة (مستودعات مدينة واحدة) وتصل كاملةً،
  /// فرحلة شبكة لكل حرف لا تشتري شيئاً.
  List<WarehousePicker> get _visible {
    if (_search.isEmpty) return _warehouses;
    final q = _search.toLowerCase();
    return _warehouses
        .where(
          (w) =>
              w.name.toLowerCase().contains(q) ||
              w.city.toLowerCase().contains(q),
        )
        .toList();
  }

  void _openCatalog(WarehousePicker warehouse) =>
      context.push(TRoutes.phWarehouseCatalogOf(warehouse.id, warehouse.name));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'كاتالوج المستودعات'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton();
    if (_error != null) return ErrorState.of(_error!, onRetry: _load);

    if (_warehouses.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: AppSpacing.x3l),
          EmptyState(
            icon: Icons.warehouse_outlined,
            message:
                'لا مستودعات تخدم مدينتك حالياً — تواصل مع الدعم لإضافة '
                'مستودعات لمنطقتك',
          ),
        ],
      );
    }

    final visible = _visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: AppSearchBar(
            controller: _searchController,
            hint: 'ابحث عن مستودع…',
            onChanged: (v) => setState(() => _search = v.trim()),
            onClearTap: () {
              _searchController.clear();
              setState(() => _search = '');
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${visible.length} '
                  '${visible.length == 1 ? 'مستودع يخدم' : 'مستودعاً يخدم'} منطقتك',
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.hint,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: visible.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: AppSpacing.x2l),
                    EmptyState(
                      icon: Icons.search_off,
                      message: 'لا مستودع يطابق بحثك',
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.x3l,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _WarehouseCard(
                      warehouse: visible[i],
                      onTap: () => _openCatalog(visible[i]),
                      onProfile: () => context.push(
                        TRoutes.phWarehouseProfile(visible[i].id),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// بطاقة مستودع — مُركَّبة من AppCard لا مكوّناً جديداً في نظام التصميم:
// لا تتكرّر خارج هذه الشاشة، وإضافتها هناك تُثقل المكتبة بما لا يُعاد
// استعماله.
class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({
    required this.warehouse,
    required this.onTap,
    required this.onProfile,
  });

  final WarehousePicker warehouse;
  final VoidCallback onTap;
  final VoidCallback onProfile;

  /// «يقبل خلال ٢–٣ أيام» — نطاقٌ إن حدّده المستودع، وإلا متوسطه الفعلي.
  ///
  /// النطاق التزامٌ أعلنه، والمتوسط قياسٌ لما فعل — والأول أصدق وعداً
  /// حين يوجد.
  String? get _speedLine {
    final min = warehouse.minAcceptanceDays;
    final max = warehouse.maxAcceptanceDays;
    if (min != null && max != null) {
      return 'يقبل الطلب خلال ${_days(min)}–${_days(max)} يوم';
    }

    final avg = warehouse.avgAcceptanceDays;
    if (avg != null && avg > 0) return 'متوسط القبول ${_days(avg)} يوم';
    return null;
  }

  static String _days(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: AppIcon(
                    AppIcons.warehouse,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warehouse.name,
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${warehouse.governorate} — ${warehouse.city}',
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // العملة تُعلَن على البطاقة: أسعار المستودع كلّها بها بلا
              // تحويل، وهو فرقٌ يُغيّر قرار الشراء قبل فتح الكتالوج.
              _Pill(label: warehouse.pricingCurrency),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _meta(
                context,
                AppIcons.mapPin,
                // «يخدم كل المناطق» التزامٌ أضعف من عددٍ صريح، والفرق
                // يهمّ الصيدلي فيُقال كما هو.
                warehouse.servesAllAreas
                    ? 'يخدم كل المناطق'
                    : 'يخدم ${warehouse.serviceAreaCount} مدينة',
              ),
              if (_speedLine case final speed?)
                _meta(context, AppIcons.clock, speed),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'تصفّح الكتالوج',
                  icon: Icons.inventory_2_outlined,
                  compact: true,
                  onPressed: onTap,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                label: 'الملف',
                icon: Icons.info_outline,
                fullWidth: false,
                compact: true,
                variant: AppButtonVariant.tonal,
                onPressed: onProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, AppIcons icon, String text) {
    final tk = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: tk.hint),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall?.copyWith(color: tk.hint)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(label, style: context.text.labelSmall),
    );
  }
}
