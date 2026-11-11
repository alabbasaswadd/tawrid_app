import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';

// بطاقة عرض بيع — شريط لوني جانبي يعكس الحالة + سطر وصفي + معاينة أصناف
// كرقاقات + قائمة إجراءات اختيارية. كل الألوان/الخطوط من الثيم (تدعم الدارك).
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

  Color _statusColor(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return switch (offer.status) {
      SalesOfferStatus.active => t.success,
      SalesOfferStatus.draft => t.warning,
      SalesOfferStatus.expired => cs.onSurfaceVariant,
      SalesOfferStatus.cancelled => cs.error,
    };
  }

  bool get _hasActions =>
      (onPublish != null && offer.status == SalesOfferStatus.draft) ||
      (onCancel != null &&
          (offer.status == SalesOfferStatus.draft || offer.status == SalesOfferStatus.active));

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final statusColor = _statusColor(context);
    final regionLabel = offer.targetRegions.isEmpty
        ? null
        : offer.targetRegions.length == 1
            ? offer.targetRegions.first.label
            : '${offer.targetRegions.first.label} +${offer.targetRegions.length - 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: statusColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium)),
                      if (_hasActions)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 20, color: context.tokens.hint),
                          onSelected: (v) {
                            if (v == 'publish') onPublish?.call();
                            if (v == 'cancel') onCancel?.call();
                          },
                          itemBuilder: (context) => [
                            if (onPublish != null && offer.status == SalesOfferStatus.draft)
                              const PopupMenuItem(value: 'publish', child: Text('نشر العرض')),
                            if (onCancel != null &&
                                (offer.status == SalesOfferStatus.draft || offer.status == SalesOfferStatus.active))
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('إلغاء العرض', style: TextStyle(color: cs.error)),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      Flexible(
                        child: Text(
                          '${offer.status.label} · ${offer.offerType.label} · ${formatSmartTimestamp(offer.createdOn)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
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
                      Icon(Icons.location_on_outlined, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(regionLabel ?? 'بلا منطقة محدَّدة',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      ),
                      Text(offer.currency,
                          style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
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
                          child: const Text('التفاصيل'),
                        ),
                      ),
                      Container(width: 1, height: 16, color: cs.outline),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                          onPressed: onComments,
                          child: const Text('التعليقات'),
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
    final cs = context.colors;
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? t.surfaceAlt : cs.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: muted ? t.hint : cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
