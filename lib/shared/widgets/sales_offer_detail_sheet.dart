import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/status_chip.dart';

// ورقة تفاصيل عرض بيع كاملة — تُفتح من بطاقة العرض في الصفحة الرئيسية أو
// صفحة "عروضي"، وتعرض كل الحقول (الوصف، المنطقة، العملة، الأصناف بكامل
// تفاصيلها، وشروط المبيع إن وُجدت).
class SalesOfferDetailSheet extends StatefulWidget {
  const SalesOfferDetailSheet({required this.load, super.key});

  final Future<SalesOfferDetail> Function() load;

  static Future<void> show(
    BuildContext context, {
    required Future<SalesOfferDetail> Function() load,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SalesOfferDetailSheet(load: load),
    );
  }

  @override
  State<SalesOfferDetailSheet> createState() => _SalesOfferDetailSheetState();
}

class _SalesOfferDetailSheetState extends State<SalesOfferDetailSheet> {
  SalesOfferDetail? _offer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offer = await widget.load();
      setState(() {
        _offer = offer;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  Color _statusColor(SalesOfferStatus status) => switch (status) {
        SalesOfferStatus.active => TawridColors.success,
        SalesOfferStatus.draft => TawridColors.hint,
        SalesOfferStatus.expired => TawridColors.textSecondary,
        SalesOfferStatus.cancelled => TawridColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_loading) {
          return const SafeArea(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingState()));
        }
        if (_error != null) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorState(message: _error!, onRetry: _load),
            ),
          );
        }
        final offer = _offer!;

        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(offer.title,
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                  StatusChip(label: offer.status.label, color: _statusColor(offer.status)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(formatSmartTimestamp(offer.createdOn),
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.hint)),
              if (offer.description != null && offer.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(offer.description!, style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, height: 1.5)),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _DetailChip(icon: Icons.sell_outlined, label: offer.offerType.label),
                  _DetailChip(icon: Icons.payments_outlined, label: offer.currency),
                  _DetailChip(
                    icon: Icons.timer_outlined,
                    label: 'ينتهي ${formatSmartTimestamp(offer.expiresAt)}',
                  ),
                ],
              ),
              if (offer.targetRegions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('المناطق المستهدفة', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in offer.targetRegions)
                      _DetailChip(icon: Icons.location_on_outlined, label: r.label),
                  ],
                ),
              ],
              if (offer.offerType == SalesOfferType.consignment) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Text('شروط المبيع', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                if (offer.upfrontPercentage != null)
                  Text('نسبة الدفع المقدَّم: ${offer.upfrontPercentage}%',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                if (offer.paymentPeriodDays != null)
                  Text('مدة السداد: ${offer.paymentPeriodDays} يوماً',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                if (offer.consignmentTerms != null && offer.consignmentTerms!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(offer.consignmentTerms!, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              Text('الأصناف (${offer.items.length})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ...offer.items.map((item) => _OfferItemTile(item: item, currency: offer.currency)),
            ],
          ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TawridColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TawridColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: TawridColors.textSecondary)),
        ],
      ),
    );
  }
}

class _OfferItemTile extends StatelessWidget {
  const _OfferItemTile({required this.item, required this.currency});
  final SalesOfferItem item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.medicineName, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 4,
              children: [
                _DetailChip(icon: Icons.inventory_2_outlined, label: '${item.quantity} ${item.unit}'),
                _DetailChip(
                  icon: Icons.sell_outlined,
                  label: '${item.unitPrice} $currency',
                ),
                if (item.discountPercentage != null)
                  _DetailChip(icon: Icons.percent, label: 'حسم ${item.discountPercentage}%'),
                if (item.bonusPercentage != null)
                  _DetailChip(icon: Icons.card_giftcard_outlined, label: 'بونص ${item.bonusPercentage}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
