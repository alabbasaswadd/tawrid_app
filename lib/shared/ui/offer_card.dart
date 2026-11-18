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
  final String itemsPreview;
  final String warehouse;
  final String expiryText;
  final String minOrderText;
  final String totalPrice;
  final OfferCardStatus status;
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
        vertical: AppSpacing.md,
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
          // ── الرأس: العنوان + شارة الحالة ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemsPreview,
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_headerBadge(context) case final badge?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.sm,
                  ),
                  child: badge,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── بيانات: المستودع + تاريخ الانتهاء ──────────────────────────
          Row(
            children: [
              Flexible(
                child: _Meta(icon: AppIcons.warehouse, text: warehouse),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: _Meta(
                  icon: AppIcons.clock,
                  text: expiryText,
                  color: status == OfferCardStatus.expiring ? t.warning : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // ── التغطية ────────────────────────────────────────────────────
          Text(
            minOrderText,
            style: context.text.labelSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: cs.outline),
          const SizedBox(height: AppSpacing.sm),

          // ── الإجمالي ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(totalLabel, style: context.text.labelSmall),
              Text(totalPrice, style: context.priceBrandStyle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── الإجراءات ──────────────────────────────────────────────────
          if (onAdd != null)
            Row(
              children: [
                Expanded(
                  child: _AddButton(
                    label: addLabel,
                    onTap: unavailable || paused ? null : onAdd,
                    dimmed: unavailable,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _DetailsLink(label: detailsLabel, onTap: onDetails),
              ],
            )
          else
            _DetailsButtonFull(label: detailsLabel, onTap: onDetails),
        ],
      ),
    );

    // البطاقة كلها مدخلٌ إلى التفاصيل — هدفٌ أوسع بكثير من رابط نصّي في
    // زاويتها. الزرّ يبقى لأنه يُسمّي الوجهة لمن لا يخمّن أن البطاقة تُضغط.
    final tappable = onDetails == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDetails,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: card,
            ),
          );

    return paused ? Opacity(opacity: 0.6, child: tappable) : tappable;
  }

  Widget? _headerBadge(BuildContext context) {
    final t = context.tokens;
    return switch (status) {
      OfferCardStatus.normal => null,
      // شارة البونص قابلة للنقر → تفاصيل العرض
      OfferCardStatus.bonus => GestureDetector(
        onTap: onDetails,
        child: BonusBadge(label: statusLabel ?? 'بونص', compact: true),
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

// شارة رأس البطاقة: pill صغيرة.
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
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(color: fg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// صف بيانات ثانوية: أيقونة + نص مع حماية الفيض.
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
        Flexible(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: c),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// زر «إضافة للطلبية» — يمتد بالكامل داخل Expanded.
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 9,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: context.text.bodySmall?.copyWith(
                      color: cs.onPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

// رابط «تفاصيل العرض» — حجمه يتناسب مع محتواه.
class _DetailsLink extends StatelessWidget {
  const _DetailsLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 9,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.bodySmall?.copyWith(color: cs.primary),
              maxLines: 1,
            ),
            const SizedBox(width: 2),
            AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// زر «تفاصيل العرض» حين لا يوجد زر إضافة — يأخذ كامل العرض.
class _DetailsButtonFull extends StatelessWidget {
  const _DetailsButtonFull({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Material(
      color: t.brandSurface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.text.bodySmall?.copyWith(color: cs.primary),
              ),
              const SizedBox(width: 4),
              AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
