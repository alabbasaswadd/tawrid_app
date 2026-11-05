import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/cart_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// السلّة (Figma: «الصيدلي / سلة التسوّق» — 199:1941).
//
// الصفحة قائمة مسطّحة لا بطاقات مستودعات مغلّفة: لكل مستودع رأسٌ خفيف
// (اسمه وعدد أصنافه)، ثم أصنافه، ثم إجماله، ثم زرّ إتمام طلبيته وحده،
// ويفصل بين مستودع وآخر خطّ رفيع. وحدة الإتمام مستودع واحد — ولذلك لا
// زرّ «طلب الكل» في التصميم، والملاحظة في أسفل الصفحة تقول ذلك صراحةً:
// أرسل طلبية مستودع الآن واترك الباقي في السلّة.
class PhCartPage extends ConsumerStatefulWidget {
  const PhCartPage({super.key});

  @override
  ConsumerState<PhCartPage> createState() => _PhCartPageState();
}

class _PhCartPageState extends ConsumerState<PhCartPage> {
  /// معرّف المستودع الجاري إتمام طلبيته — يُظهر التحميل على زرّه وحده.
  String? _checkingOut;

  /// معرّف السطر الجاري تعديل كميته — يمنع ضغطتين متلاحقتين على المنتقي.
  String? _busyLine;

  Future<void> _setQuantity(CartItem item, int value) async {
    if (_busyLine != null) return;
    setState(() => _busyLine = item.id);
    try {
      await ref.read(cartProvider.notifier).setQuantity(item.id, value);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busyLine = null);
    }
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      await ref.read(cartProvider.notifier).removeItem(item.id);
      if (mounted) {
        AppSnackbar.show(context, 'حُذف «${item.medicineName}» من السلّة');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  Future<void> _checkout(CartWarehouseGroup group) async {
    if (_checkingOut != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إتمام طلبية هذا المستودع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ستُنشأ طلبية توريد إلى «${group.warehouseName}» تضم '
              '${group.itemsLabel} بحالة «بانتظار التأكيد».',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'الإجمالي: ${formatMoneyWith(group.total, group.currency)}',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إنشاء الطلبية')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingOut = group.supplyWarehouseId);
    try {
      final result = await ref
          .read(cartProvider.notifier)
          .checkout(group.supplyWarehouseId);
      if (!mounted) return;
      AppSnackbar.success(
          context, 'أُنشئت الطلبية ${result.order.orderNumber}');
      if (result.cart.isEmpty) context.go(TRoutes.phOrders);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _checkingOut = null);
    }
  }

  Future<void> _removeWarehouse(CartWarehouseGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستودع من السلّة'),
        content: Text(
          'ستُحذف أصناف «${group.warehouseName}» من سلّتك (${group.itemsLabel}).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(cartProvider.notifier)
          .clearWarehouse(group.supplyWarehouseId);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: const InnerTopBar(title: 'السلة'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(cartProvider.notifier).refresh(),
        child: switch (cartAsync) {
          AsyncLoading() => const AppListSkeleton(count: 3),
          AsyncError(:final error) => ErrorState(
              message: ApiException.from(error).message,
              onRetry: () => ref.read(cartProvider.notifier).refresh(),
            ),
          AsyncData(:final value) => _buildBody(value),
        },
      ),
    );
  }

  Widget _buildBody(Cart cart) {
    if (cart.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.x3l),
          UiEmpty(
            appIcon: AppIcons.shoppingCart,
            message: 'سلّتك فارغة',
            description:
                'ابحث عن دواء وقارن أسعاره بين المستودعات، ثم أضف ما تحتاجه.',
            actionLabel: 'بحث الأسعار',
            onAction: () => context.push(TRoutes.phPriceSearch),
          ),
        ],
      );
    }

    final cs = context.colors;

    return ListView(
      // Figma: هامش الصفحة ٢٠، وأول رأس مستودع على بُعد ٤ من الشريط العلوي.
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.x3l),
      children: [
        for (var i = 0; i < cart.groups.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(height: 1, color: cs.outline),
            const SizedBox(height: AppSpacing.xl),
          ],
          _WarehouseGroupSection(
            group: cart.groups[i],
            checkingOut: _checkingOut == cart.groups[i].supplyWarehouseId,
            busyLineId: _busyLine,
            onCheckout: () => _checkout(cart.groups[i]),
            onRemoveWarehouse: () => _removeWarehouse(cart.groups[i]),
            onQuantityChanged: _setQuantity,
            onRemoveItem: _removeItem,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _CartSummaryCard(cart: cart),
        const SizedBox(height: AppSpacing.lg),
        const _IndependentOrdersNote(),
      ],
    );
  }
}

// ── مجموعة مستودع: رأس + أصناف + إجمالي + زرّ إتمام مستقل ────────────────
class _WarehouseGroupSection extends StatelessWidget {
  const _WarehouseGroupSection({
    required this.group,
    required this.checkingOut,
    required this.busyLineId,
    required this.onCheckout,
    required this.onRemoveWarehouse,
    required this.onQuantityChanged,
    required this.onRemoveItem,
  });

  final CartWarehouseGroup group;
  final bool checkingOut;
  final String? busyLineId;
  final VoidCallback onCheckout;
  final VoidCallback onRemoveWarehouse;
  final void Function(CartItem item, int value) onQuantityChanged;
  final void Function(CartItem item) onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final meets = group.meetsMinimum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WarehouseHeader(group: group, onRemove: onRemoveWarehouse),
        const SizedBox(height: AppSpacing.md),

        for (var i = 0; i < group.items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Dismissible(
            key: ValueKey(group.items[i].id),
            direction: DismissDirection.horizontal,
            background: const _SwipeToDeleteBackground(),
            secondaryBackground: const _SwipeToDeleteBackground(),
            onDismissed: (_) => onRemoveItem(group.items[i]),
            child: _CartItemCard(
              item: group.items[i],
              busy: busyLineId == group.items[i].id,
              onQuantityChanged: (v) => onQuantityChanged(group.items[i], v),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),
        Text(
          'إجمالي هذا المستودع: '
          '${formatMoneyWith(group.total, group.currency)}',
          textAlign: TextAlign.start,
          style: context.text.labelSmall?.copyWith(color: cs.onSurface),
        ),

        if (!meets) ...[
          const SizedBox(height: AppSpacing.sm),
          _MinimumWarning(group: group),
          const SizedBox(height: AppSpacing.sm),
        ] else
          const SizedBox(height: AppSpacing.md),

        AppButton(
          label: meets
              ? 'إتمام طلبية هذا المستودع — '
                  '${formatMoneyWith(group.total, group.currency)}'
              : 'إتمام طلبية هذا المستودع',
          loading: checkingOut,
          onPressed: (meets && !checkingOut) ? onCheckout : null,
        ),
      ],
    );
  }
}

// رأس المجموعة (Figma 199:1955): اسم المستودع في بداية القراءة وأيقونته
// بعده، وعدد الأصناف في نهايتها.
class _WarehouseHeader extends StatelessWidget {
  const _WarehouseHeader({required this.group, required this.onRemove});

  final CartWarehouseGroup group;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return GestureDetector(
      // التصميم لا يحمل زرّ حذف للمستودع، والضغط المطوّل يبقي الإجراء
      // متاحاً بلا عنصر إضافي على الشاشة.
      onLongPress: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    group.warehouseLabel,
                    style: context.text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIcon(AppIcons.warehouse, size: 16, color: cs.primary),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            group.itemsLabel,
            style: context.text.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

// بطاقة صنف (Figma 199:1963): اسم الدواء وسعر وحدته في بداية القراءة،
// إجمالي السطر في نهايتها، ومنتقي الكمية أسفلها يساراً.
class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.busy,
    required this.onQuantityChanged,
  });

  final CartItem item;
  final bool busy;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final qty = item.quantityInt;
    final bonus = item.bonusPercentage;
    final hasBonus = bonus != null && bonus > 0;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      style: context.text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'سعر الوحدة: '
                      '${formatMoneyWith(item.unitPrice, item.currency)}',
                      style:
                          context.text.bodySmall?.copyWith(color: cs.onSurface),
                    ),
                    if (item.fromOffer && item.salesOfferTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ضمن عرض: ${item.salesOfferTitle}',
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // نهاية القراءة: «الإجمالي» فوق مبلغ السطر، محاذيان لحافّتها.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الإجمالي',
                    style:
                        context.text.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    formatMoneyWith(item.lineTotal, item.currency),
                    style: context.priceStyle,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasBonus)
                BonusBadge(label: 'بونص ${bonus.toStringAsFixed(0)}٪')
              else
                const SizedBox.shrink(),
              QuantityStepper(
                value: '$qty',
                enabled: !busy,
                onDecrement: () => onQuantityChanged(qty - 1),
                onIncrement: () => onQuantityChanged(qty + 1),
                onValueChanged: onQuantityChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// تنبيه الحدّ الأدنى (Figma 199:1979): سطر كهرماني بأيقونة في نهاية القراءة.
class _MinimumWarning extends StatelessWidget {
  const _MinimumWarning({required this.group});

  final CartWarehouseGroup group;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final minimum = group.minimumOrderAmount ?? 0;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: tk.warningSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        // Figma: الأيقونة يسار النصّ والنصّ محاذٍ لليمين.
        textDirection: TextDirection.ltr,
        children: [
          AppIcon(AppIcons.alertTriangle, size: 18, color: tk.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'الحدّ الأدنى لهذا المستودع '
              '${formatMoneyWith(minimum, group.currency)} — أضف '
              '${formatMoneyWith(group.missingAmount, group.currency)} '
              'أخرى أو احذف هذا المستودع من السلة.',
              textAlign: TextAlign.right,
              style: context.text.labelSmall?.copyWith(color: tk.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ملخّص السلّة (Figma 200:178) — التسمية يساراً والقيمة يميناً كما في التصميم.
class _CartSummaryCard extends StatelessWidget {
  const _CartSummaryCard({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(label: 'عدد الأصناف', value: '${cart.totalLines}'),
          const SizedBox(height: 10),
          _SummaryRow(
              label: 'عدد المستودعات', value: '${cart.totalWarehouses}'),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'الإجمالي العام',
            value: formatMoneyWith(cart.grandTotal, cart.currency),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // التسمية تتقلّص قبل المبلغ: الرقم هو ما جاء المستخدم ليقرأه.
        Flexible(
          child: Text(
            label,
            style: context.text.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(value, style: context.priceStyle),
      ],
    );
  }
}

// ملاحظة التصميم (Figma 200:188): لماذا لا يوجد زرّ «طلب الكل».
class _IndependentOrdersNote extends StatelessWidget {
  const _IndependentOrdersNote();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        AppIcon(AppIcons.warehouse, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'أكمل كل طلبية مستودع بشكل مستقل — يمكنك إرسال طلبية مستودع الآن '
            'وترك أصناف مستودع آخر في السلّة لإكمالها لاحقاً.',
            textAlign: TextAlign.right,
            style: context.text.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

// خلفية السحب للحذف.
class _SwipeToDeleteBackground extends StatelessWidget {
  const _SwipeToDeleteBackground();

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tk.dangerSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          AppIcon(AppIcons.x, size: 18, color: tk.danger),
          const Spacer(),
          Text('حذف',
              style: context.text.bodySmall?.copyWith(color: tk.danger)),
        ],
      ),
    );
  }
}
