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
// كل مستودع يظهر ككارد مستقل يُلخَّص فيه الإجمالي وعدد الأصناف وحالة
// الحدّ الأدنى. التفاصيل (الأصناف والكميات) تُفتح في ورقة سفلية بزرّ
// «عرض التفاصيل» — لا تُكدَّس الشاشة كلها بصفوف الأصناف.
class PhCartPage extends ConsumerStatefulWidget {
  const PhCartPage({super.key});

  @override
  ConsumerState<PhCartPage> createState() => _PhCartPageState();
}

class _PhCartPageState extends ConsumerState<PhCartPage> {
  /// معرّف المستودع الجاري إتمام طلبيته — يُظهر التحميل على زرّه وحده.
  String? _checkingOut;

  /// معرّفات المستودعات الجارية في «طلب الكل».
  bool _checkingAll = false;

  Future<void> _openDetail(CartWarehouseGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CartDetailSheet(
        group: group,
        checkingOut: _checkingOut == group.supplyWarehouseId,
        onCheckout: () => _checkout(group),
      ),
    );
  }

  Future<void> _checkout(CartWarehouseGroup group) async {
    if (_checkingOut != null || _checkingAll) return;

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

    // أغلق الورقة السفلية إن كانت مفتوحة
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();

    setState(() => _checkingOut = group.supplyWarehouseId);
    try {
      final result =
          await ref.read(cartProvider.notifier).checkout(group.supplyWarehouseId);
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

  Future<void> _checkoutAll(Cart cart) async {
    final eligible = cart.groups.where((g) => g.meetsMinimum).toList();
    final blocked = cart.groups.where((g) => !g.meetsMinimum).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب كل الطلبيات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيُنشأ ${eligible.length} '
              '${eligible.length == 1 ? 'طلبية' : 'طلبيات'} '
              'لـ ${eligible.map((g) => g.warehouseName).join(' و ')}.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'الإجمالي: ${formatMoneyWith(eligible.fold(0.0, (s, g) => s + g.total), cart.currency)}',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            if (blocked.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'لن تُرسَل طلبية ${blocked.map((g) => g.warehouseName).join(' و ')} '
                'لعدم استيفاء الحدّ الأدنى.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال الطلبيات')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingAll = true);
    int sent = 0;
    for (final group in eligible) {
      if (!mounted) break;
      try {
        final result =
            await ref.read(cartProvider.notifier).checkout(group.supplyWarehouseId);
        sent++;
        if (result.cart.isEmpty) {
          if (mounted) context.go(TRoutes.phOrders);
          return;
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.error(
              context, '${group.warehouseName}: ${ApiException.from(e).message}');
        }
      }
    }
    if (mounted) {
      setState(() => _checkingAll = false);
      if (sent > 0) {
        AppSnackbar.success(
            context, 'أُنشئ $sent ${sent == 1 ? 'طلبية' : 'طلبيات'} بنجاح');
        context.go(TRoutes.phOrders);
      }
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
            style: FilledButton.styleFrom(
                backgroundColor: context.colors.error),
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
      bottomNavigationBar: cartAsync.value == null || cartAsync.value!.isEmpty
          ? null
          : _buildBottomBar(cartAsync.value!),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.x3l),
      itemCount: cart.groups.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _WarehouseSummaryCard(
          group: cart.groups[i],
          checkingOut: _checkingOut == cart.groups[i].supplyWarehouseId,
          onDetails: () => _openDetail(cart.groups[i]),
          onCheckout: () => _checkout(cart.groups[i]),
          onRemove: () => _removeWarehouse(cart.groups[i]),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Cart cart) {
    final tk = context.tokens;
    final cs = context.colors;
    final eligible = cart.groups.where((g) => g.meetsMinimum).length;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        child: AppButton(
          label: eligible == 0
              ? 'طلب كل الطلبيات'
              : 'طلب كل الطلبيات ($eligible)',
          loading: _checkingAll,
          onPressed: (_checkingAll || _checkingOut != null || eligible == 0)
              ? null
              : () => _checkoutAll(cart),
        ),
      ),
    );
  }
}

// ── كارد ملخّص مستودع ─────────────────────────────────────────────────────
class _WarehouseSummaryCard extends StatelessWidget {
  const _WarehouseSummaryCard({
    required this.group,
    required this.checkingOut,
    required this.onDetails,
    required this.onCheckout,
    required this.onRemove,
  });

  final CartWarehouseGroup group;
  final bool checkingOut;
  final VoidCallback onDetails;
  final VoidCallback onCheckout;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline),
          boxShadow: tk.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── رأس الكارد ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tk.brandSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: AppIcon(AppIcons.warehouse, size: 22,
                          color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.warehouseName,
                            style: context.text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        if (group.city.isNotEmpty)
                          Row(
                            children: [
                              AppIcon(AppIcons.mapPin, size: 12, color: tk.hint),
                              const SizedBox(width: 3),
                              Text(
                                '${group.city}، ${group.governorate}',
                                style: context.text.bodySmall
                                    ?.copyWith(color: tk.hint),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (!group.meetsMinimum)
                    const StatusBadge(
                        label: 'لم يكتمل الحدّ', tone: StatusTone.warning)
                  else
                    const StatusBadge(
                        label: 'جاهز للإرسال', tone: StatusTone.success),
                ],
              ),
            ),

            // ── الإجمالي وعدد الأصناف ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الإجمالي', style: context.text.labelSmall
                            ?.copyWith(color: tk.hint)),
                        Text(
                          formatMoneyWith(group.total, group.currency),
                          style: context.priceBrandStyle,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الأصناف', style: context.text.labelSmall
                          ?.copyWith(color: tk.hint)),
                      Text(group.itemsLabel, style: context.text.titleSmall),
                    ],
                  ),
                ],
              ),
            ),

            if (!group.meetsMinimum) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                child: _MinimumHint(group: group),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: cs.outline),

            // ── تذييل: التفاصيل وإتمام الطلبية ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  // زر حذف المستودع
                  IconButton(
                    onPressed: onRemove,
                    icon: AppIcon(AppIcons.x, size: 16,
                        color: context.tokens.danger),
                    tooltip: 'حذف من السلّة',
                  ),
                  const Spacer(),
                  // زر عرض التفاصيل
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: AppIcon(AppIcons.package, size: 15,
                        color: cs.primary),
                    label: Text('عرض التفاصيل',
                        style: context.text.bodySmall
                            ?.copyWith(color: cs.primary)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // زر الإتمام
                  FilledButton(
                    onPressed: (group.meetsMinimum && !checkingOut)
                        ? onCheckout
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      textStyle: context.text.bodySmall,
                    ),
                    child: checkingOut
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('إتمام الطلبية'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// تنبيه الحدّ الأدنى المختصر — يظهر داخل الكارد.
class _MinimumHint extends StatelessWidget {
  const _MinimumHint({required this.group});
  final CartWarehouseGroup group;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: tk.warningSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.alertTriangle, size: 14, color: tk.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'ينقص ${formatMoneyWith(group.missingAmount, group.currency)} '
              'للحدّ الأدنى',
              style: context.text.labelSmall?.copyWith(color: tk.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ورقة تفاصيل مستودع ──────────────────────────────────────────────────
class _CartDetailSheet extends ConsumerStatefulWidget {
  const _CartDetailSheet({
    required this.group,
    required this.checkingOut,
    required this.onCheckout,
  });

  final CartWarehouseGroup group;
  final bool checkingOut;
  final VoidCallback onCheckout;

  @override
  ConsumerState<_CartDetailSheet> createState() => _CartDetailSheetState();
}

class _CartDetailSheetState extends ConsumerState<_CartDetailSheet> {
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

  // الأصناف الحالية من الـ provider لا من group المُمرَّرة، حتى تُحدَّث
  // فورياً بعد التعديل بلا إعادة فتح الورقة.
  CartWarehouseGroup? get _liveGroup {
    final cart = ref.watch(cartProvider).value;
    return cart?.groups.where(
      (g) => g.supplyWarehouseId == widget.group.supplyWarehouseId,
    ).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final group = _liveGroup ?? widget.group;
    final cs = context.colors;
    final tk = context.tokens;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          // مقبض
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),

          // رأس: اسم المستودع
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tk.brandSurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: AppIcon(AppIcons.warehouse, size: 18,
                        color: cs.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.warehouseName,
                          style: context.text.titleMedium),
                      if (group.city.isNotEmpty)
                        Text(
                          '${group.city}، ${group.governorate}',
                          style: context.text.bodySmall
                              ?.copyWith(color: tk.hint),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: cs.outline),

          // الأصناف
          Expanded(
            child: group.items.isEmpty
                ? Center(
                    child: Text('لا أصناف في هذا المستودع',
                        style: context.text.bodySmall
                            ?.copyWith(color: tk.hint)),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md,
                        AppSpacing.lg, AppSpacing.md),
                    itemCount: group.items.length,
                    itemBuilder: (_, i) {
                      final item = group.items[i];
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.horizontal,
                          background:
                              const _SwipeToDeleteBackground(),
                          secondaryBackground:
                              const _SwipeToDeleteBackground(),
                          onDismissed: (_) => _removeItem(item),
                          child: _CartLineCard(
                            item: item,
                            currency: group.currency,
                            busy: _busyLine == item.id,
                            onQuantityChanged: (v) =>
                                _setQuantity(item, v),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // تنبيه الحدّ الأدنى
          if (!group.meetsMinimum)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                  AppSpacing.lg, AppSpacing.sm),
              child: _FullMinimumWarning(group: group),
            ),

          // الإجمالي وزرّ الإتمام
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outline)),
              ),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('إجمالي هذا المستودع',
                            style: context.text.bodyMedium),
                      ),
                      Text(formatMoneyWith(group.total, group.currency),
                          style: context.priceBrandStyle),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: group.meetsMinimum
                        ? 'إتمام الطلبية — '
                              '${formatMoneyWith(group.total, group.currency)}'
                        : 'إتمام الطلبية',
                    loading: widget.checkingOut,
                    onPressed: group.meetsMinimum ? widget.onCheckout : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// تنبيه الحدّ الأدنى الكامل — داخل الورقة السفلية.
class _FullMinimumWarning extends StatelessWidget {
  const _FullMinimumWarning({required this.group});
  final CartWarehouseGroup group;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: tk.warningSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(AppIcons.alertTriangle, size: 18,
                color: tk.warning),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'الحدّ الأدنى لهذا المستودع '
              '${formatMoneyWith(group.minimumOrderAmount ?? 0, group.currency)}'
              ' — أضف ${formatMoneyWith(group.missingAmount, group.currency)}'
              ' أخرى لاستيفاء الحدّ الأدنى.',
              style: context.text.labelSmall?.copyWith(color: tk.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// بطاقة صنف في الورقة (نفس تصميم الأصلي).
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
        border: Border.all(color: cs.outline),
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
                      'سعر الوحدة: ${formatMoneyWith(item.unitPrice, item.currency)}',
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
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: QuantityStepper(
              value: '$qty',
              enabled: !busy,
              onDecrement: () => onQuantityChanged(qty - 1),
              onIncrement: () => onQuantityChanged(qty + 1),
              onValueChanged: onQuantityChanged,
            ),
          ),
        ],
      ),
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
