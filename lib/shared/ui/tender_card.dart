import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';
import 'status_badge.dart';

// بطاقة طلب التسعير للصيدلي (Figma: بطاقة طلب تسعير) — الصيدلي ينشر
// طلباً بأصناف وكميات محددة والمستودعات تردّ بعروض أسعار. تعرض: الحالة
// (مفتوح/مغلق/مسودة)، الأصناف المطلوبة، الموعد النهائي، منطقة التسليم،
// عدد العروض المستلمة، ورابط المقارنة.
class TenderCard extends StatelessWidget {
  const TenderCard({
    required this.title,
    required this.itemsText,
    required this.deadlineText,
    required this.deliveryText,
    required this.statusLabel,
    this.statusTone = StatusTone.brand,
    this.offersCountLabel,
    this.compareLabel = 'عرض العروض والمقارنة',
    this.onCompare,
    this.onTap,
    super.key,
  });

  // «طلب تسعير — أدوية القلب».
  final String title;

  // «٦ أصناف مطلوبة · كميات محددة».
  final String itemsText;

  // «استقبال العروض حتى بعد غدٍ ٦ مساءً».
  final String deadlineText;

  // «التسليم: إدلب — سراقب».
  final String deliveryText;
  final String statusLabel;
  final StatusTone statusTone;

  // «٤ عروض مستلمة».
  final String? offersCountLabel;
  final String compareLabel;
  final VoidCallback? onCompare;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: t.cardShadow,
      ),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: context.text.titleMedium),
                    ),
                    StatusBadge(label: statusLabel, tone: statusTone),
                  ],
                ),
                const SizedBox(height: 10),
                _Meta(icon: AppIcons.package, text: itemsText),
                const SizedBox(height: 10),
                _Meta(icon: AppIcons.clock, text: deadlineText),
                const SizedBox(height: 10),
                _Meta(icon: AppIcons.mapPin, text: deliveryText),
                const SizedBox(height: 10),
                Divider(color: cs.outline),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (offersCountLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: t.brandSurface,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          offersCountLabel!,
                          style: context.text.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    InkWell(
                      onTap: onCompare,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            compareLabel,
                            style: context.text.bodySmall?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          AppIcon(
                            AppIcons.chevronForwardRtl,
                            size: 14,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final AppIcons icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.onSurfaceVariant;
    return Row(
      children: [
        AppIcon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}
