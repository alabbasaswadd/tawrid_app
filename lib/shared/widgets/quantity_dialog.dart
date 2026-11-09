import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

/// حوار تحديد الكمية قبل الإضافة إلى السلّة.
///
/// مشترك بين «بحث الأسعار» و«كاتالوج المستودعات»: نسختان منه كانتا تفترقان
/// في الكمية الابتدائية وفي وجود سطر التلميح، والفارق يُقرأ تناقضاً لا
/// تنوّعاً. يُعيد الكمية، أو `null` إن أُلغي.
///
/// [initialQuantity] تأتي من كمية العرض المعلنة حيث وُجدت — فالمستودع يعرض
/// الصنف بكمية بعينها، وبدء العدّاد من واحد يُجبر الصيدلي على بلوغها نقراً.
Future<int?> showQuantityDialog(
  BuildContext context, {
  required String medicineName,
  int initialQuantity = 1,
  String? hint,
  int maxQuantity = 9999,
}) {
  var qty = initialQuantity.clamp(1, maxQuantity);

  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('تحديد الكمية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              medicineName,
              style: ctx.text.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                hint,
                style: ctx.text.labelSmall?.copyWith(color: ctx.tokens.hint),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'الكمية:',
                  style: ctx.text.bodySmall?.copyWith(color: ctx.tokens.hint),
                ),
                const SizedBox(width: AppSpacing.sm),
                QuantityStepper(
                  value: '$qty',
                  onDecrement: qty > 1 ? () => setS(() => qty--) : null,
                  onIncrement:
                      qty < maxQuantity ? () => setS(() => qty++) : null,
                  onValueChanged: (v) =>
                      setS(() => qty = v.clamp(1, maxQuantity)),
                  onLiveChanged: (v) =>
                      setS(() => qty = v.clamp(1, maxQuantity)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, qty),
            child: const Text('أضف للسلة'),
          ),
        ],
      ),
    ),
  );
}
