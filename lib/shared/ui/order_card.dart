import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';
import 'status_badge.dart';

// بطاقة الطلب الموحدة للتطبيقين (Figma: بطاقة طلب): رقم الطلب والجهة
// والحالة والقيمة، مع إجراء واحد (عرض التفاصيل).
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.title,
    required this.subtitle,
    required this.metaText,
    required this.price,
    required this.statusLabel,
    this.statusTone = StatusTone.brand,
    this.detailsLabel = 'عرض التفاصيل',
    this.onDetails,
    super.key,
  });

  // «طلب رقم TW-1024».
  final String title;

  // «مستودع الشفاء — دمشق».
  final String subtitle;

  // «أُنشئ في ١٢ ذو القعدة · ٨ أصناف».
  final String metaText;
  final String price;
  final String statusLabel;
  final StatusTone statusTone;
  final String detailsLabel;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline),
        boxShadow: t.cardShadow,
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
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.text.bodySmall),
                  ],
                ),
              ),
              StatusBadge(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metaText, style: context.text.labelSmall),
                    Text(price, style: context.priceStyle),
                  ],
                ),
              ),
              InkWell(
                onTap: onDetails,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detailsLabel,
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
    );
  }
}
