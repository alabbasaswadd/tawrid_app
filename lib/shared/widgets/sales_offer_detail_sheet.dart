import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/status_chip.dart';

double _priceAfter(SalesOfferItem i) => i.unitPrice * (1 - (i.discountPercentage ?? 0) / 100);
String _fmt(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

// ورقة تفاصيل عرض بيع — عرض واضح للسعر قبل/بعد والحسم والبونص (صنف/عرض)،
// مع مشاركة كملف PDF.
class SalesOfferDetailSheet extends StatefulWidget {
  const SalesOfferDetailSheet({required this.load, this.onWarehouseTap, super.key});

  final Future<SalesOfferDetail> Function() load;

  // جهة الصيدلي تمرّر فتح ملف المستودع؛ جهة المستودع تتركها null فلا يُعرض
  // اسمه كرابط إلى ملفه العام — لا معنى لذلك وهو صاحب العرض.
  final void Function(String warehouseId)? onWarehouseTap;

  static Future<void> show(
    BuildContext context, {
    required Future<SalesOfferDetail> Function() load,
    void Function(String warehouseId)? onWarehouseTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SalesOfferDetailSheet(load: load, onWarehouseTap: onWarehouseTap),
    );
  }

  @override
  State<SalesOfferDetailSheet> createState() => _SalesOfferDetailSheetState();
}

class _SalesOfferDetailSheetState extends State<SalesOfferDetailSheet> {
  SalesOfferDetail? _offer;
  bool _loading = true;
  bool _sharing = false;
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

  Color _statusColor(SalesOfferStatus s) => switch (s) {
        SalesOfferStatus.active => context.tokens.success,
        SalesOfferStatus.draft => context.tokens.warning,
        SalesOfferStatus.expired => context.colors.onSurfaceVariant,
        SalesOfferStatus.cancelled => context.colors.error,
      };

  Future<void> _sharePdf(SalesOfferDetail offer) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _buildPdf(offer);
      await Printing.sharePdf(bytes: bytes, filename: 'عرض-${offer.title}.pdf');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'تعذّرت المشاركة: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_loading) {
          return const SafeArea(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingState()));
        }
        if (_error != null) {
          return SafeArea(
            child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: ErrorState(message: _error!, onRetry: _load)),
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
                  Expanded(child: Text(offer.title, style: context.text.titleLarge)),
                  StatusChip(label: offer.status.label, color: _statusColor(offer.status)),
                ],
              ),
              const SizedBox(height: 2),
              if (widget.onWarehouseTap == null)
                Text('${offer.warehouseName} · ${formatSmartTimestamp(offer.createdOn)}',
                    style: context.text.bodySmall)
              else
                Row(
                  children: [
                    InkWell(
                      onTap: () => widget.onWarehouseTap!(offer.supplyWarehouseId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(offer.warehouseName,
                              style: context.text.bodySmall
                                  ?.copyWith(color: context.colors.primary)),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_left,
                              size: 15, color: context.colors.primary),
                        ],
                      ),
                    ),
                    Text(' · ${formatSmartTimestamp(offer.createdOn)}',
                        style: context.text.bodySmall),
                  ],
                ),
              if (offer.description != null && offer.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(offer.description!, style: context.text.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _chip(context, Icons.sell_outlined, '${offer.items.length} صنف'),
                  _chip(context, Icons.payments_outlined, offer.currency),
                  _chip(context, Icons.timer_outlined, 'ينتهي ${formatSmartTimestamp(offer.expiresAt)}'),
                ],
              ),
              if (offer.targetRegions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('المناطق المستهدفة', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [for (final r in offer.targetRegions) _chip(context, Icons.location_on_outlined, r.label)],
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              const Divider(),
              Text('الأصناف (${offer.items.length})', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ...offer.items.map((item) => _ItemCard(item: item, currency: offer.currency)),

              if (offer.bonusMedicineName != null && offer.bonusMedicineName!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.tokens.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.tokens.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, color: context.tokens.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بونص العرض: ${offer.bonusMedicineName}'
                          '${offer.bonusMedicineQuantity != null ? ' × ${_fmt(offer.bonusMedicineQuantity!)} ${offer.bonusMedicineUnit ?? ''}' : ''}',
                          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // شروط الدفع تُعرض متى وُجدت — لا ترتبط بنوع عرض بعد حذفه
              if (offer.upfrontPercentage != null ||
                  offer.paymentPeriodDays != null ||
                  (offer.consignmentTerms?.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                Text('شروط الدفع', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                if (offer.upfrontPercentage != null)
                  Text('نسبة الدفع المقدَّم: ${offer.upfrontPercentage}%', style: context.text.bodyMedium),
                if (offer.paymentPeriodDays != null)
                  Text('مدة السداد: ${offer.paymentPeriodDays} يوماً', style: context.text.bodyMedium),
                if (offer.consignmentTerms != null && offer.consignmentTerms!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(offer.consignmentTerms!, style: context.text.bodyMedium)),
              ],

              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _sharing ? null : () => _sharePdf(offer),
                icon: _sharing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_sharing ? 'جارٍ التجهيز...' : 'مشاركة كملف PDF'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: context.tokens.surfaceAlt, borderRadius: BorderRadius.circular(AppSpacing.chipRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.currency});
  final SalesOfferItem item;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final hasDiscount = (item.discountPercentage ?? 0) > 0;
    final after = _priceAfter(item);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.medicineName, style: context.text.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              if (hasDiscount) ...[
                Text('${_fmt(item.unitPrice)} ',
                    style: context.text.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: context.tokens.hint)),
                Text('${_fmt(after)} $currency', style: context.text.titleSmall?.copyWith(color: cs.primary)),
                const SizedBox(width: 8),
                _pill(context, 'حسم ${_fmt(item.discountPercentage!)}%', context.tokens.warning),
              ] else
                Text('${_fmt(item.unitPrice)} $currency', style: context.text.titleSmall?.copyWith(color: cs.primary)),
              const Spacer(),
              if ((item.bonusPercentage ?? 0) > 0)
                _pill(context, 'بونص ${_fmt(item.bonusPercentage!)}%', context.tokens.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── توليد PDF (عربي RTL بخط Cairo) ──────────────────────────────────────
Future<Uint8List> _buildPdf(SalesOfferDetail offer) async {
  final base = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document();

  final rows = offer.items
      .map((i) => [
            i.medicineName,
            _fmt(i.unitPrice),
            (i.discountPercentage ?? 0) > 0 ? '${_fmt(i.discountPercentage!)}%' : '-',
            _fmt(_priceAfter(i)),
            (i.bonusPercentage ?? 0) > 0 ? '${_fmt(i.bonusPercentage!)}%' : '-',
          ])
      .toList();

  doc.addPage(pw.MultiPage(
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: base, bold: bold),
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      pw.Text(offer.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('المستودع: ${offer.warehouseName} · ${offer.warehousePhone}'),
      pw.Text('عدد الأصناف: ${offer.items.length} · العملة: ${offer.currency}'),
      pw.Text('ينتهي: ${offer.expiresAt.toString().split(' ').first}'),
      if (offer.description != null && offer.description!.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(offer.description!),
      ],
      pw.SizedBox(height: 14),
      pw.Text('الأصناف', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['الدواء', 'السعر قبل', 'الحسم', 'السعر بعد', 'البونص'],
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E8B73)),
        cellAlignment: pw.Alignment.centerRight,
        cellStyle: const pw.TextStyle(fontSize: 10),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F5)),
      ),
      if (offer.bonusMedicineName != null && offer.bonusMedicineName!.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFE8F5EE), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(
            'بونص العرض: ${offer.bonusMedicineName}'
            '${offer.bonusMedicineQuantity != null ? ' × ${_fmt(offer.bonusMedicineQuantity!)} ${offer.bonusMedicineUnit ?? ''}' : ''}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
      if (offer.upfrontPercentage != null ||
          offer.paymentPeriodDays != null ||
          (offer.consignmentTerms?.isNotEmpty ?? false)) ...[
        pw.SizedBox(height: 10),
        pw.Text('شروط الدفع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (offer.upfrontPercentage != null) pw.Text('نسبة الدفع المقدَّم: ${offer.upfrontPercentage}%'),
        if (offer.paymentPeriodDays != null) pw.Text('مدة السداد: ${offer.paymentPeriodDays} يوماً'),
        if (offer.consignmentTerms != null && offer.consignmentTerms!.isNotEmpty) pw.Text(offer.consignmentTerms!),
      ],
      pw.SizedBox(height: 16),
      pw.Text('توريد — منصة التوريد الدوائي', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
    ],
  ));

  return doc.save();
}
