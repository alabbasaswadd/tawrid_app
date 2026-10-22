import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';

// بطاقة عرض بيع — تصميم مُعاد بالكامل: شريط لوني جانبي يعكس الحالة بدل
// شارة مؤطَّرة، سطر وصفي مختصر (نوع · وقت) بلا أيقونات متكررة، معاينة
// لأصناف العرض كرقاقات مميّزة بصرياً، وقائمة إجراءات (⋮) اختيارية لتغيير
// الحالة بدل أزرار تذييل إضافية. مُعاد استخدامها في الصفحة الرئيسية
// وصفحة "عروضي".
class SalesOfferPostCard extends StatelessWidget {
  const SalesOfferPostCard({
    required this.offer,
    required this.onDetails,
    required this.onComments,
    this.onPublish,
    this.onCancel,
    super.key,
  });

  final SalesOfferSummary offer;
  final VoidCallback onDetails;
  final VoidCallback onComments;
  final VoidCallback? onPublish;
  final VoidCallback? onCancel;

  Color get _statusColor => switch (offer.status) {
        SalesOfferStatus.active => TawridColors.success,
        SalesOfferStatus.draft => TawridColors.warning,
        SalesOfferStatus.expired => TawridColors.textSecondary,
        SalesOfferStatus.cancelled => TawridColors.error,
      };

  bool get _hasActions =>
      (onPublish != null && offer.status == SalesOfferStatus.draft) ||
      (onCancel != null &&
          (offer.status == SalesOfferStatus.draft || offer.status == SalesOfferStatus.active));

  @override
  Widget build(BuildContext context) {
    final regionLabel = offer.targetRegions.isEmpty
        ? null
        : offer.targetRegions.length == 1
            ? offer.targetRegions.first.label
            : '${offer.targetRegions.first.label} +${offer.targetRegions.length - 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: TawridColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TawridColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: _statusColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      ),
                      if (_hasActions)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, size: 20, color: TawridColors.hint),
                          onSelected: (v) {
                            if (v == 'publish') onPublish?.call();
                            if (v == 'cancel') onCancel?.call();
                          },
                          itemBuilder: (context) => [
                            if (onPublish != null && offer.status == SalesOfferStatus.draft)
                              const PopupMenuItem(value: 'publish', child: Text('نشر العرض')),
                            if (onCancel != null &&
                                (offer.status == SalesOfferStatus.draft ||
                                    offer.status == SalesOfferStatus.active))
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Text('إلغاء العرض', style: TextStyle(color: TawridColors.error)),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                      ),
                      Flexible(
                        child: Text(
                          '${offer.status.label} · ${offer.offerType.label} · ${formatSmartTimestamp(offer.createdOn)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 11.5, color: TawridColors.hint),
                        ),
                      ),
                    ],
                  ),
                  if (offer.itemNames.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final name in offer.itemNames) _ItemPill(label: name),
                        if (offer.itemCount > offer.itemNames.length)
                          _ItemPill(label: '+${offer.itemCount - offer.itemNames.length}', muted: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: TawridColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          regionLabel ?? 'بلا منطقة محدَّدة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 12, color: TawridColors.textSecondary),
                        ),
                      ),
                      Text(offer.currency,
                          style: GoogleFonts.cairo(
                              fontSize: 12, color: TawridColors.textSecondary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Divider(height: 1),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                          onPressed: onDetails,
                          child: Text('التفاصيل', style: GoogleFonts.cairo(fontSize: 12.5)),
                        ),
                      ),
                      Container(width: 1, height: 16, color: TawridColors.border),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                          onPressed: onComments,
                          child: Text('التعليقات', style: GoogleFonts.cairo(fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemPill extends StatelessWidget {
  const _ItemPill({required this.label, this.muted = false});
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? TawridColors.surfaceVariant : TawridColors.warehouse.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: muted ? TawridColors.hint : TawridColors.warehouse,
        ),
      ),
    );
  }
}
