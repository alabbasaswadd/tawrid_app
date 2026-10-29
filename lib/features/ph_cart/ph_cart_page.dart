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

// السلّة (Figma: الصيدلي / سلة التسوّق).
//
// مجمَّعة حسب المستودع لأن **وحدة الإتمام مستودع واحد**: لكل مجموعة إجمالها
// وزر إتمامها المستقلّ، وقد يُرسل الصيدلي طلبية مستودع الآن ويترك أصناف
// مستودع آخر في السلّة لإكمالها لاحقاً. التجميع والإجماليات وحالة الحدّ
// الأدنى كلها من الخادم — لا حساب محلّي يفترق عنه.
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
      if (mounted) AppSnackbar.show(context, 'حُذف «${item.medicineName}» من السلّة');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  Future<void> _removeWarehouse(CartWarehouseGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستودع من السلّة'),
        content: Text(
          'ستُحذف أصناف «${group.warehouseName}» من سلّتك '
          '(${group.itemsLabel}). لا يؤثر ذلك في طلبياتك المُرسَلة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(cartProvider.notifier).clearWarehouse(group.supplyWarehouseId);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  Future<void> _checkout(CartWarehouseGroup group) async {
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
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'الإجمالي: ${formatMoneyWith(group.total, group.currency)}',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'أصناف المستودعات الأخرى تبقى في سلّتك لإكمالها لاحقاً.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إنشاء الطلبية'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _checkingOut = group.supplyWarehouseId);
    try {
      final result = await ref
          .read(cartProvider.notifier)
          .checkout(group.supplyWarehouseId);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُنشئت الطلبية ${result.order.orderNumber}');

      // السلّة فرغت تماماً → لا شيء يُبقي الشاشة مفتوحة؛ وإلا تبقى
      // لإكمال مجموعة أخرى.
      if (result.cart.isEmpty) context.go(TRoutes.phOrders);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _checkingOut = null);
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
                'ابحث عن دواء وقارن أسعاره بين المستودعات، ثم أضف ما تحتاجه '
                'إلى السلّة.',
            actionLabel: 'بحث الأسعار',
            onAction: () => context.push(TRoutes.phPriceSearch),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        for (var i = 0; i < cart.groups.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(color: context.colors.outline, height: 1),
            const SizedBox(height: AppSpacing.xl),
          ],
          _WarehouseGroup(
            group: cart.groups[i],
            busyLineId: _busyLine,
            checkingOut: _checkingOut == cart.groups[i].supplyWarehouseId,
            onQuantityChanged: _setQuantity,
            onRemoveItem: _removeItem,
            onRemoveWarehouse: () => _removeWarehouse(cart.groups[i]),
            onCheckout: () => _checkout(cart.groups[i]),
          ),
        ],

        const SizedBox(height: AppSpacing.x2l),
        _CartSummary(cart: cart),

        const SizedBox(height: AppSpacing.md),
        // الملاحظة التي تشرح لماذا لا يوجد زرّ «إتمام الكل»: كل مستودع
        // طلبية مستقلّة، لا معاملة واحدة تجمعها.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(
                AppIcons.warehouse,
                size: 14,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'أكمل كل طلبية مستودع بشكل مستقل — يمكنك إرسال طلبية مستودع '
                'الآن وترك أصناف مستودع آخر في السلّة لإكمالها لاحقاً.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// مجموعة مستودع واحد: رأس (الاسم + عدد الأصناف)، بطاقات الأصناف، إجمالي
// المجموعة، تنبيه الحدّ الأدنى عند النقص، ثم زر الإتمام.
class _WarehouseGroup extends StatelessWidget {
  const _WarehouseGroup({
    required this.group,
    required this.busyLineId,
    required this.checkingOut,
    required this.onQuantityChanged,
    required this.onRemoveItem,
    required this.onRemoveWarehouse,
    required this.onCheckout,
  });

  final CartWarehouseGroup group;
  final String? busyLineId;
  final bool checkingOut;
  final void Function(CartItem item, int value) onQuantityChanged;
  final void Function(CartItem item) onRemoveItem;
  final VoidCallback onRemoveWarehouse;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الرأس: اسم المستودع في بداية القراءة مع أيقونته، وعدد الأصناف
        // في الطرف المقابل.
        Row(
          children: [
            AppIcon(AppIcons.warehouse, size: 16, color: cs.onSurface),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                group.warehouseLabel,
                style: context.text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(group.itemsLabel, style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        for (final item in group.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            // السحب هو طريقة الحذف (مع إنقاص الكمية إلى صفر) — لا أيقونة
            // حذف في البطاقة، فالتصميم يُبقي الصفّ للكمية وحدها.
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.horizontal,
              background: const _SwipeToDeleteBackground(),
              secondaryBackground: const _SwipeToDeleteBackground(),
              onDismissed: (_) => onRemoveItem(item),
              child: _CartLineCard(
                item: item,
                currency: group.currency,
                busy: busyLineId == item.id,
                onQuantityChanged: (v) => onQuantityChanged(item, v),
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'إجمالي هذا المستودع: '
            '${formatMoneyWith(group.total, group.currency)}',
            style: context.text.labelSmall,
          ),
        ),

        if (!group.meetsMinimum) ...[
          const SizedBox(height: AppSpacing.md),
          _MinimumWarning(group: group, onRemoveWarehouse: onRemoveWarehouse),
        ],

        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: group.meetsMinimum
              ? 'إتمام طلبية هذا المستودع — '
                    '${formatMoneyWith(group.total, group.currency)}'
              : 'إتمام طلبية هذا المستودع',
          loading: checkingOut,
          // دون الحدّ الأدنى: الزر معطَّل والتنبيه فوقه يقول كم ينقص ولماذا.
          onPressed: group.meetsMinimum ? onCheckout : null,
        ),
      ],
    );
  }
}

// بطاقة صنف في السلّة (Figma): الإجمالي في الطرف، والاسم وسعر الوحدة في
// بداية القراءة، ثم منتقي الكمية وحده. سطح بلا حدّ وزاوية ١٢ وحشوة ١٣.
class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.item,
    required this.currency,
    required this.busy,
    required this.onQuantityChanged,
  });

  final CartItem item;
  final String currency;
  final bool busy;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final qty = item.quantityInt;

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
                      style: context.text.bodySmall,
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
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الإجمالي', style: context.text.bodySmall),
                  Text(
                    formatMoneyWith(item.lineTotal, item.currency),
                    style: context.priceStyle,
                  ),
                ],
              ),
            ],
          ),

          if (item.bonusPercentage != null && item.bonusPercentage! > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BonusBadge(
                label: 'بونص ${item.bonusPercentage!.toStringAsFixed(0)}٪',
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          // المنتقي وحده في نهاية القراءة (كما في Figma) — لا زرّ حذف:
          // الحذف بالسحب أفقياً أو بإنقاص الكمية إلى صفر.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: QuantityStepper(
              value: '$qty',
              enabled: !busy,
              // الإنقاص عند ١ يحذف السطر — الخادم يعامل الصفر حذفاً.
              onDecrement: () => onQuantityChanged(qty - 1),
              onIncrement: () => onQuantityChanged(qty + 1),
              // الكتابة المباشرة: كمية ٢٤٠ لا تُبلَغ بالضغط ٢٤٠ مرة.
              onValueChanged: onQuantityChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// تنبيه الحدّ الأدنى — سطح التحذير، يقول كم ينقص وما البديل.
class _MinimumWarning extends StatelessWidget {
  const _MinimumWarning({required this.group, required this.onRemoveWarehouse});

  final CartWarehouseGroup group;
  final VoidCallback onRemoveWarehouse;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: tk.warningSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(AppIcons.alertTriangle, size: 18, color: tk.warning),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحدّ الأدنى لهذا المستودع '
                  '${formatMoneyWith(group.minimumOrderAmount ?? 0, group.currency)} — '
                  'أضف ${formatMoneyWith(group.missingAmount, group.currency)} '
                  'أخرى أو احذف هذا المستودع من السلّة.',
                  style: context.text.labelSmall?.copyWith(color: tk.warning),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onRemoveWarehouse,
                  child: Text(
                    'حذف هذا المستودع من السلّة',
                    style: context.text.labelSmall?.copyWith(
                      color: tk.warning,
                      decoration: TextDecoration.underline,
                      decorationColor: tk.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ملخّص السلّة: عدد الأصناف، عدد المستودعات، الإجمالي العام.
class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          _row(context, 'عدد الأصناف', '${cart.totalLines}'),
          const SizedBox(height: 10),
          _row(context, 'عدد المستودعات', '${cart.totalWarehouses}'),
          const SizedBox(height: 10),
          _row(
            context,
            'الإجمالي العام',
            formatMoneyWith(cart.grandTotal, cart.currency),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Row(
    children: [
      Expanded(child: Text(label, style: context.text.bodyMedium)),
      Text(value, style: context.priceStyle),
    ],
  );
}


// خلفية السحب للحذف — تظهر خلف البطاقة أثناء السحب في أي اتجاه، فيرى
// المستخدم ما سيحدث قبل أن يُفلت.
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
          Text(
            'حذف',
            style: context.text.bodySmall?.copyWith(color: tk.danger),
          ),
        ],
      ),
    );
  }
}
