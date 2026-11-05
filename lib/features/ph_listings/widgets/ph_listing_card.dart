import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// بطاقة إعلان «صيدلي إلى صيدلي» — تُعرض في قائمة التصفح وقائمة إعلاناتي.
class PhListingCard extends StatelessWidget {
  const PhListingCard({
    required this.listing,
    required this.onTap,
    this.isOwner = false,
    super.key,
  });

  final PhListingSummary listing;
  final VoidCallback onTap;

  /// عند true تُظهر شارة الحجوزات المعلقة (للمالك).
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final l = listing;

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
                  ? tk.warning.withValues(alpha: .4)
                  : cs.outline,
            ),
            boxShadow: tk.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── رأس البطاقة ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.medicineName,
                            style: context.text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (l.genericName != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              l.genericName!,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AppIcon(AppIcons.user, size: 11, color: tk.hint),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  l.pharmacyName,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: tk.hint),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          label: l.reason.label,
                          tone: _reasonTone(l.reason),
                        ),
                        if (l.isListingExpired) ...[
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: 'منتهي الصلاحية',
                            tone: StatusTone.danger,
                          ),
                        ],
                        if (isOwner && l.pendingBookingsCount > 0) ...[
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: '${l.pendingBookingsCount} طلب حجز',
                            tone: StatusTone.info,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── خط فاصل ──────────────────────────────────────────────────
              Divider(height: 1, color: cs.outline),

              // ── تفاصيل الكمية والسعر والموقع ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DetailChip(
                            icon: AppIcons.package,
                            text: '${l.quantity} وحدة',
                            color: tk.hint,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _DetailChip(
                            icon: AppIcons.tag,
                            text:
                                '${l.pricePerUnit.toStringAsFixed(0)} ل.س/الوحدة',
                            color: cs.primary,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailChip(
                            icon: AppIcons.mapPin,
                            text: l.city.isEmpty
                                ? l.governorate
                                : '${l.city} · ${l.governorate}',
                            color: tk.hint,
                          ),
                        ),
                        if (l.expiryDate != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _DetailChip(
                              icon: AppIcons.clock,
                              text:
                                  'صلاحية الدواء: ${_formatDate(l.expiryDate!)}',
                              color: tk.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _DetailChip(
                      icon: AppIcons.clock,
                      text: _listingExpiryLabel(l.listingExpiresAt, l.status),
                      color: l.isListingExpired
                          ? tk.danger
                          : l.status == PhListingStatus.booked
                              ? tk.hint
                              : tk.hint,
                    ),
                    if (l.notes != null && l.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l.notes!,
                          style: context.text.bodySmall
                              ?.copyWith(color: tk.hint),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── تذييل ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _timeAgo(l.createdOn),
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                    Row(
                      children: [
                        Text(
                          isOwner ? 'تفاصيل الإعلان' : 'تفاصيل وحجز',
                          style: context.text.bodySmall
                              ?.copyWith(color: cs.primary),
                        ),
                        const SizedBox(width: 2),
                        AppIcon(AppIcons.chevronForwardRtl,
                            size: 14, color: cs.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static StatusTone _reasonTone(PhListingReason r) => switch (r) {
        PhListingReason.nearExpiry => StatusTone.warning,
        PhListingReason.slowMoving => StatusTone.neutral,
        PhListingReason.overstocked => StatusTone.info,
        PhListingReason.other => StatusTone.neutral,
      };

  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

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

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  final AppIcons icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: (context.text.bodySmall ?? const TextStyle()).copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
