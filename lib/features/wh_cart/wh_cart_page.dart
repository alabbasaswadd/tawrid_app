import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/wh_cart.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// سلة المستودع — أصناف مختارة من أدوية المستودع لإنشاء عرض بيع سريع.
class WhCartPage extends ConsumerWidget {
  const WhCartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(whCartProvider);
    final notifier = ref.read(whCartProvider.notifier);

    return Scaffold(
      appBar: InnerTopBar(
        title: 'السلة${items.isNotEmpty ? ' (${items.length})' : ''}',
        trailing: items.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'إفراغ السلة',
                onPressed: () => _confirmClear(context, notifier),
              )
            : null,
      ),
      body: items.isEmpty
          ? const _EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.sm,
                        AppSpacing.page,
                        AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _CartItemTile(
                      item: items[i],
                      onRemove: () => notifier.remove(items[i].warehouseMedicineId),
                    ),
                  ),
                ),
                _BottomBar(
                  count: items.length,
                  onCreateOffer: () {
                    notifier.clear();
                    context.push(TRoutes.whCreateOffer);
                  },
                ),
              ],
            ),
    );
  }

  void _confirmClear(BuildContext context, WhCartNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: const Text('هل تريد إزالة جميع الأصناف من السلة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.clear();
            },
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item, required this.onRemove});
  final WhCartItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [item.genericName, item.dosageForm.label]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style:
                      context.text.bodySmall?.copyWith(color: tk.hint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: context.colors.error),
            onPressed: onRemove,
            tooltip: 'إزالة',
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.count, required this.onCreateOffer});
  final int count;
  final VoidCallback onCreateOffer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
        child: AppButton(
          label: 'إنشاء عرض من هذه الأصناف ($count)',
          icon: Icons.add,
          onPressed: onCreateOffer,
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.tokens.brandSurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.shoppingCart,
                  size: 34,
                  color: context.colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('السلة فارغة', style: context.text.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: Text(
                'أضف أصنافاً من قائمة أدوية مستودعك لإنشاء عرض بيع سريع',
                textAlign: TextAlign.center,
                style: context.text.bodySmall
                    ?.copyWith(color: context.tokens.hint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
