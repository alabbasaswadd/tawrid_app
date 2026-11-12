import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/models/bonus_tier.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/bonus_tiers.dart';
import 'package:tawrid_app/shared/utils/money.dart';

/// حوار تحديد الكمية قبل الإضافة إلى السلّة.
///
/// مشترك بين «بحث الأسعار» و«كاتالوج المستودعات»: نسختان منه كانتا تفترقان
/// في الكمية الابتدائية وفي وجود سطر التلميح، والفرق يُقرأ تناقضاً لا تنوّعاً.
/// يُعيد الكمية، أو `null` إن أُلغي.
///
/// **حين يحمل الصنف شرائح بونص** يصير الحوار واعياً بها: يبدأ من أصغر كمية
/// تستحقّ بونصاً، ويقفز بخطوتها لا بواحد، ويعرض ما سيناله مجاناً عند كل
/// كمية. فشريحة ‎(10+2)‎ تبدأ من ‎10‎ وتقفز إلى ‎20‎ — بدل أن يبدأ من واحد
/// فيضغط ‎+‎ تسعاً ليبلغ عتبةً لا يعلم بها.
///
/// وبلا شرائح يعمل كما كان: يبدأ من [initialQuantity] ويقفز بواحد.
///
/// القراءة مبنيّة على أربعة صناديق لا على عمودٍ من أسطرٍ متجاورة: مَن الصنف،
/// كم الكمية، ماذا تربح، وكم تدفع. كانت الأسطر الستّة متمركزةً بلا فواصل
/// فتُقرأ فقرةً واحدة، ولا يُعرف أيُّها جوابُ أيِّ سؤال.
Future<int?> showQuantityDialog(
  BuildContext context, {
  required String medicineName,
  int initialQuantity = 1,
  String? hint,
  int maxQuantity = 9999,
  List<BonusTier> tiers = const [],
  String unit = 'علبة',
  double? unitPrice,
  String? currency,
  String? warehouseName,
}) {
  // أصغر كمية شراء في السلّم: هي عتبة أوّل بونص، وهي خطوة الزيادة.
  final step = quantityStepFor(tiers);

  final start = tiers.isEmpty
      ? initialQuantity.clamp(1, maxQuantity)
      : step.clamp(1, maxQuantity);

  var qty = start;

  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final tk = ctx.tokens;
        final cs = ctx.colors;
        final free = freeQuantityFor(tiers, qty.toDouble());
        final next = _nextThreshold(tiers, qty);

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          title: Text('تحديد الكمية', style: ctx.text.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ١ — مَن الصنف: الاسم عنواناً، والمستودع والتلميح سطراً
                // خافتاً تحته. محاذاةً لبداية القراءة لا توسيطاً: الأسماء
                // العربية الطويلة تُقرأ أسرع من حافّةٍ ثابتة.
                Text(
                  medicineName,
                  style: ctx.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (warehouseName != null || hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [?warehouseName, ?hint].join(' · '),
                    style: ctx.text.labelSmall?.copyWith(color: tk.hint),
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // ٢ — كم الكمية: التسمية في بداية السطر والمِعداد في نهايته،
                // داخل إطارٍ يفصله عمّا حوله. كان المِعداد متمركزاً فيبدو
                // عرضاً لا حقلاً يُملأ.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('الكمية', style: ctx.text.bodyMedium),
                            if (step > 1)
                              Text(
                                'تزيد وتنقص بـ $step',
                                style: ctx.text.labelSmall?.copyWith(
                                  color: tk.hint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      QuantityStepper(
                        value: '$qty',
                        onDecrement: qty > 1
                            ? () => setS(() {
                                // النزول بالخطوة نفسها، وأدناه واحد لا صفر.
                                qty = (qty - step).clamp(1, maxQuantity);
                              })
                            : null,
                        onIncrement: qty < maxQuantity
                            ? () => setS(() {
                                qty = (qty + step).clamp(1, maxQuantity);
                              })
                            : null,
                        // الكتابة اليدوية تبقى حرّة: الخطوة اقتراحٌ لا قيد.
                        onValueChanged: (v) =>
                            setS(() => qty = v.clamp(1, maxQuantity)),
                        onLiveChanged: (v) =>
                            setS(() => qty = v.clamp(1, maxQuantity)),
                      ),
                    ],
                  ),
                ),

                // ٣ — ماذا تربح: كلّ ما يخصّ البونص في صندوقٍ ذهبيّ واحد —
                // المستحقّ الآن، وما تستلمه فعلاً، والعتبة التالية، ثمّ
                // سلّم العرض كاملاً. كانت هذه الأسطر مبعثرةً فوق المِعداد
                // وتحته فلا يُعرف أيُّها نتيجةُ الكمية المختارة.
                if (tiers.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tk.goldSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: tk.gold),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppIcon(
                              AppIcons.gift,
                              size: 18,
                              color: free > 0 ? tk.goldStrong : tk.hint,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // محسوبٌ بنفس حاسبة الخادم، فلا يختلف
                                  // الموعود عن المسلَّم.
                                  Text(
                                    free > 0
                                        ? 'تحصل على ${formatQuantity(free)} '
                                              '$unit مجاناً'
                                        : 'لا بونص عند هذه الكمية',
                                    style: ctx.text.titleSmall?.copyWith(
                                      color: free > 0 ? tk.goldStrong : tk.hint,
                                    ),
                                  ),
                                  if (free > 0)
                                    Text(
                                      'تستلم ${formatQuantity(qty + free)} '
                                      '$unit وتدفع ثمن $qty',
                                      style: ctx.text.labelSmall?.copyWith(
                                        color: tk.hint,
                                      ),
                                    ),
                                  if (next != null)
                                    Text(
                                      'أضف ${next - qty} لتبلغ $next فتحصل '
                                      'على ${formatQuantity(freeQuantityFor(tiers, next.toDouble()))}',
                                      style: ctx.text.labelSmall?.copyWith(
                                        color: tk.goldStrong,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Divider(height: 1, color: tk.gold),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'سلّم العرض',
                          style: ctx.text.labelSmall?.copyWith(color: tk.hint),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // السلّم كاملاً — ليقرّر الصيدلي كميته عن علم.
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final t in tiers)
                              BonusBadge(label: t.label, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ٤ — كم تدفع: آخر ما يُقرأ قبل الضغط على «أضف»، فهو آخر
                // صندوق. يغيب إن لم يُعرف سعر الوحدة.
                if (unitPrice != null && currency != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الإجمالي',
                          style: ctx.text.bodySmall?.copyWith(color: tk.hint),
                        ),
                      ),
                      Text(
                        formatMoneyWith(unitPrice * qty, currency),
                        style: ctx.priceStyle,
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
        );
      },
    ),
  );
}

/// أقرب كمية أعلى يزيد عندها البونص — أو `null` إن لم تعد الزيادة تنفع.
///
/// تُفحَص الكميات صعوداً بخطوةٍ واحدة حتى حدٍّ معقول: السلالم الحقيقية
/// عتباتُها صغيرة، والبحث بلا حدّ يجمّد الواجهة على سلّمٍ شاذّ.
int? _nextThreshold(List<BonusTier> tiers, int qty) {
  if (tiers.isEmpty) return null;

  final current = freeQuantityFor(tiers, qty.toDouble());
  final biggest = tiers
      .map((t) => t.buyQuantity.round())
      .fold<int>(1, (a, b) => a > b ? a : b);

  for (var q = qty + 1; q <= qty + biggest; q++) {
    if (freeQuantityFor(tiers, q.toDouble()) > current) return q;
  }
  return null;
}
