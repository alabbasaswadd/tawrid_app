import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';

// بطاقة إعلان «صيدلي إلى صيدلي» — في قائمة التصفح وقائمة إعلاناتي.
//
// البطاقة تُقرأ بنظرة لا بتدقيق، فلها ثلاث طبقات واضحة بدل صفٍّ من
// الشرائح الرمادية المتساوية:
//   ١ الرأس:  اسم الدواء وجنيسه ثم سبب البيع — ما هو هذا الإعلان.
//   ٢ الصفقة: سعر الوحدة بارزاً · الكمية · الإجمالي — الرقم هو القرار.
//   ٣ السياق: الصيدلية والمنطقة، وصلاحية الدواء وعمر الإعلان.
class PhListingCard extends StatelessWidget {
  const PhListingCard({
    required this.listing,
    required this.onTap,
    this.isOwner = false,
    super.key,
  });

  final PhListingSummary listing;
  final VoidCallback onTap;

  /// قائمة «إعلاناتي» — تغيّر نصّ التذييل وتُظهر حالة الإعلان لصاحبه.
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final l = listing;
    final dim = l.isListingExpired || l.status == PhListingStatus.closed;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: l.reason == PhListingReason.nearExpiry
                  ? tk.warning.withValues(alpha: .45)
                  : cs.outline,
            ),
            boxShadow: tk.cardShadow,
          ),
          // الإعلان المنتهي أو المغلق يبهت كله بدل شارةٍ وحدها — تُقرأ
          // حالته قبل أن يُقرأ سعره.
          child: Opacity(
            opacity: dim ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                _dealStrip(context),
                _context(context),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ١ الرأس: ما هو هذا الدواء ──────────────────────────────────────────
  Widget _header(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final l = listing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
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
              child: AppIcon(AppIcons.pill, size: 22, color: cs.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.medicineName,
                  style: context.text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (l.manufacturer != null && l.manufacturer!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.manufacturer!,
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // سقفٌ للشارة: تأخذ حاجتها ولا تزاحم اسم الدواء على العرض.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124),
            child: StatusBadge(
              label: l.reason.label,
              tone: _reasonTone(l.reason),
            ),
          ),
        ],
      ),
    );
  }

  // ── ٢ شريط الصفقة: السعر هو القرار ─────────────────────────────────────
  Widget _dealStrip(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final l = listing;
    final total = l.pricePerUnit * l.quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tk.brandSurfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          // بداية القراءة: سعر الوحدة — أكبر رقم في البطاقة.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سعر الوحدة',
                  style: context.text.labelSmall?.copyWith(color: tk.hint),
                ),
                Text(
                  formatMoneyWith(l.pricePerUnit, l.currency),
                  style: context.priceBrandStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: cs.outline),
          const SizedBox(width: AppSpacing.md),
          // نهاية القراءة: الكمية وقيمتها الكلّية — حجم الصفقة.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${l.quantity} وحدة',
                style: context.text.titleSmall,
              ),
              Text(
                'الإجمالي ${formatMoneyWith(total, l.currency)}',
                style: context.text.labelSmall?.copyWith(color: tk.hint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ٣ السياق: من أين، ومتى ينتهي ───────────────────────────────────────
  Widget _context(BuildContext context) {
    final tk = context.tokens;
    final l = listing;
    final expired = l.isListingExpired;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            icon: AppIcons.user,
            text: l.pharmacyName,
            trailingIcon: AppIcons.mapPin,
            trailingText:
                l.city.isEmpty ? l.governorate : '${l.city}، ${l.governorate}',
          ),
          if (l.expiryDate != null) ...[
            const SizedBox(height: 6),
            _Line(
              icon: AppIcons.calendar,
              text: 'صلاحية الدواء حتى ${_formatDate(l.expiryDate!)}',
              color: tk.warning,
            ),
          ],
          const SizedBox(height: 6),
          _Line(
            icon: AppIcons.clock,
            text: _listingExpiryLabel(l.listingExpiresAt, l.status),
            color: expired ? tk.danger : tk.hint,
          ),
          if (l.notes != null && l.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.notes!,
              style: context.text.bodySmall?.copyWith(color: tk.hint),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── التذييل ────────────────────────────────────────────────────────────
  Widget _footer(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final l = listing;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          Text(
            _timeAgo(l.createdOn),
            style: context.text.labelSmall?.copyWith(color: tk.hint),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Spacer(),
          Flexible(
            child: Text(
              isOwner ? 'إدارة الإعلان والردّ' : 'التفاصيل والتعليقات',
              style: context.text.bodySmall?.copyWith(color: cs.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
        ],
      ),
    );
  }

  static StatusTone _reasonTone(PhListingReason r) => switch (r) {
    PhListingReason.nearExpiry => StatusTone.warning,
    PhListingReason.slowMoving => StatusTone.neutral,
    PhListingReason.overstocked => StatusTone.info,
    PhListingReason.other => StatusTone.neutral,
  };

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return _formatDate(d);
  }

  static String _listingExpiryLabel(DateTime expiresAt, PhListingStatus status) {
    if (status == PhListingStatus.closed) return 'الإعلان مغلق';
    if (status == PhListingStatus.booked) return 'ينتهي عند الاتفاق بين الطرفين';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'انتهى الإعلان';
    if (remaining.inDays == 0) return 'الإعلان ينتهي اليوم';
    if (remaining.inDays == 1) return 'يوم واحد متبقٍ للإعلان';
    return 'متبقٍ ${remaining.inDays} أيام للإعلان';
  }
}

// سطر سياق: أيقونة ونصّ في بداية القراءة، وزوجٌ ثانٍ اختياري في نهايتها.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.color,
    this.trailingIcon,
    this.trailingText,
  });

  final AppIcons icon;
  final String text;
  final Color? color;
  final AppIcons? trailingIcon;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final c = color ?? tk.hint;
    final style = context.text.bodySmall?.copyWith(color: c);

    return Row(
      children: [
        AppIcon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null && trailingText != null) ...[
          const SizedBox(width: AppSpacing.md),
          AppIcon(trailingIcon!, size: 13, color: tk.hint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trailingText!,
              style: context.text.bodySmall?.copyWith(color: tk.hint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
