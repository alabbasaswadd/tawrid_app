import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/contact_launcher.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

StatusTone orderTone(SupplyOrderStatus s) => switch (s) {
      SupplyOrderStatus.pending => StatusTone.warning,
      SupplyOrderStatus.confirmed => StatusTone.brand,
      SupplyOrderStatus.processing => StatusTone.brand,
      SupplyOrderStatus.shipped => StatusTone.info,
      SupplyOrderStatus.delivered => StatusTone.info,
      SupplyOrderStatus.completed => StatusTone.success,
      SupplyOrderStatus.cancelled => StatusTone.danger,
    };

// تبويبات الصيدلي الثلاثة: «الجارية» تجمع كل ما لم يُغلق بعد، والمكتملة
// والملغاة حالتان نهائيتان. الخادم يفلتر بحالة واحدة فقط (`?status=`)،
// فالتجميع يتم هنا بعد الجلب بدل ثلاث رحلات شبكة.
enum _OrdersTab {
  active('الجارية'),
  completed('المكتملة'),
  cancelled('الملغاة');

  const _OrdersTab(this.label);
  final String label;

  bool matches(SupplyOrderStatus s) => switch (this) {
        _OrdersTab.active =>
          s != SupplyOrderStatus.completed && s != SupplyOrderStatus.cancelled,
        _OrdersTab.completed => s == SupplyOrderStatus.completed,
        _OrdersTab.cancelled => s == SupplyOrderStatus.cancelled,
      };

  String get countNoun => switch (this) {
        _OrdersTab.active => 'جارية',
        _OrdersTab.completed => 'مكتملة',
        _OrdersTab.cancelled => 'ملغاة',
      };
}

// طلبات التوريد عند الصيدلي (Figma: الصيدلي / الطلبات).
class PhOrdersPage extends ConsumerStatefulWidget {
  const PhOrdersPage({super.key});

  @override
  ConsumerState<PhOrdersPage> createState() => _PhOrdersPageState();
}

class _PhOrdersPageState extends ConsumerState<PhOrdersPage> {
  List<SupplyOrderSummary>? _orders;
  bool _loading = true;
  String? _error;
  _OrdersTab _tab = _OrdersTab.active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] يُحدّث البيانات بلا إظهار مؤشّر التحميل، فتبقى القائمة
  /// ظاهرة ويبقى موضع التمرير كما هو. يُستخدم عند العودة من التفاصيل:
  /// استبدال القائمة بمؤشّر دوّار لمجرّد الرجوع يبدو كإعادة تحميل كاملة.
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(supplyOrderRepositoryProvider).getMyOrders(limit: 50);
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
    await context.push(TRoutes.phOrderDetail(order.id));
    // العودة من التفاصيل قد تحمل إلغاءً أو فاتورةً مولَّدة، فالقائمة
    // تُحدَّث — لكن بصمت: لا مؤشّر ولا قفزة في موضع التمرير.
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التوريد'),
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
    if (_loading) return const AppListSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _orders ?? const <SupplyOrderSummary>[];
    final shown = all.where((o) => _tab.matches(o.status)).toList();
    final tk = context.tokens;

    return Column(
      children: [
        // شرائح الحالة (Figma): الشريحة النشطة مملوءة بلون العلامة.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
          child: Row(
            children: [
              for (final t in _OrdersTab.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: AppFilterChip(
                    label: t.label,
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                ),
            ],
          ),
        ),

        // سطر العدد (Figma: «٣ طلبيات جارية»).
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${shown.length} ${shown.length == 1 ? 'طلبية' : 'طلبيات'} ${_tab.countNoun}',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
          ),
        ),

        Expanded(
          child: shown.isEmpty
              ? ListView(
                  // ListView لا Center، ليبقى السحب للتحديث عاملاً وهي فارغة
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.local_shipping_outlined,
                      message: switch (_tab) {
                        _OrdersTab.active =>
                          'لا طلبيات جارية — تصفّح العروض وأضف ما تحتاجه',
                        _OrdersTab.completed =>
                          'لا طلبيات مكتملة بعد — منها تُولَّد فاتورة الشراء',
                        _OrdersTab.cancelled => 'لم تُلغَ أي طلبية',
                      },
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => _OrderCard(
                    order: shown[i],
                    onTap: () => _openDetails(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// بطاقة الطلب (Figma: بطاقة طلب) — رقم الطلب والحالة، الجهة، سطر البيانات،
// القيمة، ورابط التفاصيل. شريط جانبي بلون الحالة يجعل القائمة تُقرأ لمحةً.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final SupplyOrderSummary order;
  final VoidCallback onTap;

  Color _stripeColor(BuildContext context) {
    final t = context.tokens;
    return switch (order.status) {
      SupplyOrderStatus.pending => t.warning,
      SupplyOrderStatus.cancelled => context.colors.error,
      SupplyOrderStatus.completed => t.success,
      _ => context.colors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    // الشريط الجانبي طبقةٌ في Stack لا حدٌّ ولا عمود في Row:
    //  • حدّ غير منتظم مع زاوية مستديرة يرفضه Flutter عند الرسم
    //    («A borderRadius can only be given for borders with uniform colors»)
    //    فتُرسم البطاقة بيضاء بلا محتوى.
    //  • وصفٌّ بـ`stretch` داخل ListView يطلب ارتفاعاً لا نهائياً.
    // أمّا `PositionedDirectional` بـ top و bottom معاً فيمتدّ بارتفاع
    // الطبقة غير المموضعة (المحتوى) بلا قياس داخلي ولا قيود مفتوحة.
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          children: [
            Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('طلب رقم ${order.orderNumber}',
                                  style: context.text.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            StatusBadge(
                              label: order.status.label,
                              tone: orderTone(order.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${order.warehouseName} — ${order.warehouseCity}',
                            style: context.text.bodySmall?.copyWith(color: tk.hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          'أُنشئ ${formatSmartTimestamp(order.createdOn)} · '
                          '${order.itemCount} ${order.itemCount == 1 ? 'صنف' : 'أصناف'}',
                          style: context.text.labelSmall?.copyWith(color: tk.hint),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // القيمة تُخفى إن لم يُسعَّر شيء بعد — صفرٌ هنا كذب.
                            if (order.totalAmount != null)
                              Text(formatMoneyWith(order.totalAmount!, kPlatformCurrency),
                                  style: context.priceBrandStyle)
                            else
                              Text('بانتظار التسعير',
                                  style: context.text.bodySmall
                                      ?.copyWith(color: tk.hint)),
                            const Spacer(),
                            // التواصل من القائمة مباشرةً — الهاتف صار ضمن
                            // ملخّص الطلبية فلا يلزم فتح التفاصيل لمراسلة
                            // المستودع. يختفي إن لم يكن الرقم صالحاً.
                            if (whatsAppNumber(order.warehousePhone) != null)
                              InkWell(
                                onTap: () => openWhatsApp(
                                  order.warehousePhone,
                                  message: 'مرحباً، بخصوص طلبية التوريد رقم '
                                      '${order.orderNumber}',
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Icon(Icons.chat,
                                      size: 18, color: cs.primary),
                                ),
                              ),
                            const SizedBox(width: AppSpacing.xs),
                            Text('عرض التفاصيل',
                                style: context.text.bodySmall
                                    ?.copyWith(color: cs.primary)),
                            const SizedBox(width: 2),
                            AppIcon(AppIcons.chevronForwardRtl,
                                size: 14, color: cs.primary),
                          ],
                        ),
                      ],
                    ),
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: _stripeColor(context)),
            ),
          ],
        ),
      ),
    );
  }
}
