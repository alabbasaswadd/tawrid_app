import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';
import 'bonus_badge.dart';

// حالات بطاقة العرض (Figma: بطاقة عرض — ٥ حالات).
enum OfferCardStatus { normal, bonus, expiring, unavailable, paused }

// بطاقة العرض للصيدلي — العرض يشمل عدة أدوية وليس صنفاً واحداً:
// عنوان العرض، سطر معاينة الأصناف، المستودع، الانتهاء، الحد الأدنى،
// إجمالي العرض، وإجراء رئيسي واحد (إضافة للطلبية).
// البونص على مستوى العرض: شارة ذهبية + حد ذهبي رفيع للبطاقة.
class OfferCard extends StatelessWidget {
  const OfferCard({
    required this.title,
    required this.itemsPreview,
    required this.warehouse,
    required this.expiryText,
    required this.minOrderText,
    required this.totalPrice,
    this.status = OfferCardStatus.normal,
    this.statusLabel,
    this.totalLabel = 'إجمالي العرض',
    this.addLabel = 'إضافة للطلبية',
    this.detailsLabel = 'تفاصيل العرض',
    this.onAdd,
    this.onDetails,
    super.key,
  });

  final String title;

  // معاينة الأصناف: «أموكسيسيلين ٥٠٠ · سيفترياكسون ١غ · +٣ أصناف».
  final String itemsPreview;
  final String warehouse;
  final String expiryText;

  // «٥ أصناف · الحد الأدنى: ٢٠ عبوة لكل صنف».
  final String minOrderText;
  final String totalPrice;
  final OfferCardStatus status;

  // نص الشارة العلوية: بونص «بونص ١٠ + ٢» / «ينتهي قريباً» / «غير متوفر
  // حالياً» / «متوقف». عند إغفاله تُستخدم النصوص الافتراضية.
  final String? statusLabel;
  final String totalLabel;
  final String addLabel;
  final String detailsLabel;
  final VoidCallback? onAdd;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    final paused = status == OfferCardStatus.paused;
    final unavailable = status == OfferCardStatus.unavailable;

    final card = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: status == OfferCardStatus.bonus ? t.gold : cs.outline,
        ),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الرأس: العنوان في بداية القراءة + شارة الحالة في الطرف المقابل.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(itemsPreview, style: context.text.bodySmall),
                  ],
                ),
              ),
              ?_headerBadge(context),
            ],
          ),
          const SizedBox(height: 10),

          // بيانات: المستودع ثم الانتهاء (١٢ ثانوي، أيقونات ١٤).
          Row(
            children: [
              _Meta(icon: AppIcons.warehouse, text: warehouse),
              const SizedBox(width: AppSpacing.md),
              _Meta(
                icon: AppIcons.clock,
                text: expiryText,
                color: status == OfferCardStatus.expiring ? t.warning : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(minOrderText, style: context.text.labelSmall),
          const SizedBox(height: 10),
          Divider(color: cs.outline),
          const SizedBox(height: 10),

          // التذييل: السعر في بداية القراءة، والإجراءات في الطرف المقابل.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(totalLabel, style: context.text.labelSmall),
                    Text(totalPrice, style: context.priceBrandStyle),
                  ],
                ),
              ),
              if (onAdd != null) ...[
                _AddButton(
                  label: addLabel,
                  onTap: unavailable || paused ? null : onAdd,
                  dimmed: unavailable,
                ),
                const SizedBox(width: AppSpacing.md),
                InkWell(
                  onTap: onDetails,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        detailsLabel,
                        style: context.text.bodySmall?.copyWith(color: cs.primary),
                      ),
                      const SizedBox(width: 2),
                      AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
                    ],
                  ),
                ),
              ] else
                // بدون زر الإضافة: تفاصيل العرض زرٌّ أساسي بارز
                Material(
                  color: t.brandSurface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onDetails,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detailsLabel,
                            style: context.text.bodySmall?.copyWith(color: cs.primary),
                          ),
                          const SizedBox(width: 4),
                          AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return paused ? Opacity(opacity: 0.6, child: card) : card;
  }

  Widget? _headerBadge(BuildContext context) {
    final t = context.tokens;
    return switch (status) {
      OfferCardStatus.normal => null,
      OfferCardStatus.bonus => BonusBadge(
        label: statusLabel ?? 'بونص',
        compact: true,
      ),
      OfferCardStatus.expiring => _Pill(
        label: statusLabel ?? 'ينتهي قريباً',
        fg: t.warning,
        bg: t.warningSurface,
      ),
      OfferCardStatus.unavailable => _Pill(
        label: statusLabel ?? 'غير متوفر حالياً',
        fg: t.danger,
        bg: t.dangerSurface,
      ),
      OfferCardStatus.paused => _Pill(
        label: statusLabel ?? 'متوقف',
        fg: context.colors.onSurfaceVariant,
        bg: Theme.of(context).scaffoldBackgroundColor,
        bordered: true,
      ),
    };
  }
}

// شارة رأس البطاقة: pill صغيرة (نص ١١).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.bordered = false,
  });

  final String label;
  final Color fg;
  final Color bg;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: bordered ? Border.all(color: context.colors.outline) : null,
      ),
      child: Text(label, style: context.text.labelSmall?.copyWith(color: fg)),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final AppIcons icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: c)),
      ],
    );
  }
}

// زر «إضافة للطلبية» المصغّر داخل البطاقة (Figma: زاوية ١٠، نص ١٢ أبيض).
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.label,
    required this.onTap,
    this.dimmed = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(color: cs.onPrimary),
                ),
                const SizedBox(width: 4),
                AppIcon(AppIcons.plus, size: 14, color: cs.onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
