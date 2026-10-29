import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/ph_cart.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// سلة الصيدلي (Figma: السلة) — قائمة العروض المحفوظة للمراجعة والطلب.
class PhCartPage extends ConsumerWidget {
  const PhCartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(phCartProvider);
    final notifier = ref.read(phCartProvider.notifier);

    return Scaffold(
      appBar: InnerTopBar(
        title: 'سلتي${items.isNotEmpty ? ' (${items.length})' : ''}',
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
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final item = items[i];
                return Stack(
                  children: [
                    OfferSummaryCard(
                      offer: item.offer,
                      onDetails: () => context.push(TRoutes.phOfferDetail(item.offerId)),
                      onAdd: () => context.push(TRoutes.phOfferDetail(item.offerId)),
                    ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Material(
                        color: context.colors.errorContainer,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => notifier.remove(item.offerId),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: AppIcon(
                                AppIcons.x,
                                size: 14,
                                color: context.colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _confirmClear(BuildContext context, PhCartNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: const Text('هل تريد إزالة جميع العروض المحفوظة من سلتك؟'),
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
            Text('سلتك فارغة', style: context.text.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: Text(
                'أضف عروضاً من الرئيسية أو صفحة العروض لتطّلع عليها لاحقاً وتطلب منها',
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
