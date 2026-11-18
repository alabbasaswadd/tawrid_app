import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'wh_orders_page.dart' show whOrderTone;

// تفاصيل الطلب الوارد عند المستودع (Figma: المستودع / تفاصيل الطلب).
//
// شاشة قرار: من طلب، وماذا طلب بالضبط، وكم قيمته — ثم قبول أو رفض.
// الإجراءات تتبع ما يسمح به الخادم من انتقالات الحالة، لا أكثر.
class WhOrderDetailPage extends ConsumerStatefulWidget {
  const WhOrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<WhOrderDetailPage> createState() => _WhOrderDetailPageState();
}

class _WhOrderDetailPageState extends ConsumerState<WhOrderDetailPage> {
  SupplyOrderDetail? _order;
  List<StatusHistoryItem> _history = const [];
  bool _loading = true;
  bool _busy = false;
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
      final repo = ref.read(supplyOrderRepositoryProvider);
      final order = await repo.getWarehouseOrderById(widget.orderId);
      List<StatusHistoryItem> history;
      try {
        history = await repo.getWarehouseOrderHistory(widget.orderId);
      } catch (_) {
        // السجلّ تفصيل مساعد: فشله لا يمنع عرض الطلب واتخاذ القرار.
        history = const [];
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  double get _itemsTotal {
    final items = _order?.items ?? const <SupplyOrderItem>[];
    return items.fold<double>(
        0, (sum, i) => sum + (i.agreedUnitPrice ?? 0) * i.quantity);
  }

  /// عملة أسعار هذه الطلبية — مجمَّدة فيها، لا ثابتَ منصّة.
  String get _currency => _order?.currency ?? 'SYP';

  /// الكمية المجانية: يحسبها الخادم من الشرائح المركَّبة ويُجمّدها
  /// (freeQuantity)؛ والنسبة القديمة احتياطٌ لطلبيات سبقت الشرائح.
  /// هذا ما يُحضِّره المستودع فعلاً مع الطلبية.
  double get _freeUnits {
    final items = _order?.items ?? const <SupplyOrderItem>[];
    return items.fold<double>(
        0,
        (sum, i) => sum +
            (i.freeQuantity > 0
                ? i.freeQuantity
                : i.quantity * ((i.bonusPercentage ?? 0) / 100)));
  }

  Future<void> _move(SupplyOrderStatus next, {String? confirmText}) async {
    if (confirmText != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(next.label),
          content: Text(confirmText),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع')),
            FilledButton(
              style: next == SupplyOrderStatus.cancelled
                  ? FilledButton.styleFrom(backgroundColor: context.colors.error)
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(next == SupplyOrderStatus.cancelled ? 'رفض' : 'تأكيد'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(supplyOrderRepositoryProvider)
          .updateOrderStatus(widget.orderId, next);
      if (!mounted) return;
      AppSnackbar.success(context, 'حُدّثت حالة الطلب إلى «${next.label}»');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تصدير الطلب', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('تصدير إلى PDF', style: context.text.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdf();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('تصدير إلى Excel', style: context.text.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackbar.show(context, 'جاري تطوير تصدير Excel');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final order = _order;
    if (order == null) return;
    try {
      AppSnackbar.show(context, 'جاري إنشاء PDF...');
      final bytes = await _whBuildOrderPdf(order, _history, _itemsTotal, _freeUnits);
      await Printing.sharePdf(
          bytes: bytes, filename: 'طلبية-${order.orderNumber}.pdf');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'تعذّر إنشاء PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [
          if (_order != null)
            TextButton(
              onPressed: _showExportSheet,
              child: const Text('تصدير'),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _order == null ? null : _buildActions(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final o = _order!;
    final cs = context.colors;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        // بطاقة الرأس: من طلب وأين يُسلَّم ومتى وصل.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('طلب رقم ${o.orderNumber}',
                        style: context.text.titleLarge),
                  ),
                  StatusBadge(label: o.status.label, tone: whOrderTone(o.status)),
                ],
              ),
              const SizedBox(height: 10),
              _Line(
                icon: Icons.local_pharmacy_outlined,
                text: [
                  o.pharmacyName ?? 'صيدلية',
                  if ((o.pharmacyCity ?? '').isNotEmpty) o.pharmacyCity!,
                ].join(' — '),
                color: cs.primary,
              ),
              if ((o.pharmacyAddress ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                _Line(
                    icon: Icons.place_outlined,
                    text: 'عنوان التسليم: ${o.pharmacyAddress}'),
              ],
              const SizedBox(height: 6),
              _Line(
                  icon: Icons.schedule,
                  text: 'وصل ${formatSmartTimestamp(o.createdOn)}'),
              if (o.expectedDeliveryDate != null) ...[
                const SizedBox(height: 6),
                _Line(
                    icon: Icons.event_outlined,
                    text: 'التسليم المتوقع: '
                        '${formatSmartTimestamp(o.expectedDeliveryDate!)}'),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text('أصناف الطلب (${o.items.length})', style: context.text.titleLarge),
        const SizedBox(height: AppSpacing.sm),

        for (final item in o.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.medicineName, style: context.text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity.toStringAsFixed(0)} ${item.unit}'
                          '${(item.bonusPercentage ?? 0) > 0 ? ' + ${(item.quantity * item.bonusPercentage! / 100).toStringAsFixed(0)} مجاناً (بونص ${item.bonusPercentage!.toStringAsFixed(0)}٪)' : ''}',
                          style: context.text.bodySmall?.copyWith(
                            color: (item.bonusPercentage ?? 0) > 0
                                ? tk.goldStrong
                                : tk.hint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    item.agreedUnitPrice == null
                        ? '—'
                        : formatMoneyWith(
                            item.agreedUnitPrice! * item.quantity, _currency),
                    style: context.text.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'قيمة الأصناف',
                  value: formatMoneyWith(_itemsTotal, _currency)),
              if (_freeUnits > 0) ...[
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'كميات مجانية (بونص)',
                  value: '${formatQuantity(_freeUnits)} عبوة',
                  valueColor: tk.goldStrong,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Divider(height: 1, color: cs.outline),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                      child: Text('إجمالي الطلب', style: context.text.titleSmall)),
                  Text(formatMoneyWith(_itemsTotal, _currency),
                      style: context.priceBrandStyle),
                ],
              ),
            ],
          ),
        ),

        if (o.notes != null && o.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملاحظات الصيدلية', style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(o.notes!,
                    style: context.text.bodySmall?.copyWith(color: tk.hint)),
              ],
            ),
          ),
        ],

        if (_history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسار الطلب', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                for (final h in _history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${h.oldStatus.label} ← ${h.newStatus.label} · '
                      '${h.changedByName} · ${formatSmartTimestamp(h.changedAt)}',
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _contactPharmacy() async {
    final order = _order!;
    if (order.pharmacyTenantId == null) return;
    setState(() => _busy = true);
    try {
      final conv = await ref
          .read(whConversationRepositoryProvider)
          .openConversation(otherPartyId: order.pharmacyTenantId!);
      if (!mounted) return;
      context.push(TRoutes.whConversationDetail(conv.id, conv.otherPartyName));
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showActionsSheet() {
    final o = _order!;
    final next = o.status.nextAllowed;
    final forward =
        next.where((s) => s != SupplyOrderStatus.cancelled).toList();
    final canReject = next.contains(SupplyOrderStatus.cancelled);
    final cs = context.colors;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('خيارات الطلب', style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (o.pharmacyTenantId != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_outlined),
                  title: const Text('تواصل مع الصيدلية'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _contactPharmacy();
                  },
                ),
                if (forward.isNotEmpty || canReject) const Divider(height: 1),
              ],
              for (final s in forward) ...[
                if (s != forward.first) const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(switch (s) {
                    SupplyOrderStatus.confirmed => 'قبول الطلب',
                    SupplyOrderStatus.processing => 'بدء التجهيز',
                    SupplyOrderStatus.shipped => 'تأكيد الشحن',
                    SupplyOrderStatus.delivered => 'تأكيد التسليم',
                    SupplyOrderStatus.completed => 'إغلاق الطلب',
                    _ => s.label,
                  }),
                  onTap: () {
                    Navigator.pop(ctx);
                    _move(s,
                        confirmText: switch (s) {
                          SupplyOrderStatus.confirmed =>
                            'هل تريد قبول هذا الطلب والالتزام بتجهيزه؟',
                          SupplyOrderStatus.processing =>
                            'هل تريد بدء تجهيز هذا الطلب؟',
                          SupplyOrderStatus.shipped =>
                            'هل تريد تأكيد شحن هذا الطلب؟',
                          SupplyOrderStatus.delivered =>
                            'هل تريد تأكيد تسليم الطلب للصيدلية؟',
                          SupplyOrderStatus.completed =>
                            'هل تريد إغلاق هذا الطلب نهائياً؟',
                          _ =>
                            'هل تريد تغيير حالة الطلب إلى «${s.label}»؟',
                        });
                  },
                ),
              ],
              if (canReject) ...[
                if (forward.isNotEmpty) const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cancel_outlined, color: cs.error),
                  title:
                      Text('رفض الطلب', style: TextStyle(color: cs.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _move(SupplyOrderStatus.cancelled,
                        confirmText:
                            'سيُبلَّغ الصيدلية برفض الطلب، ولا يمكن التراجع عنه.');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildActions() {
    final o = _order!;

    // الشريط يبقى ما دام في الورقة ما يُفعَل — والتواصل مع الصيدلية متاح
    // دائماً. كان يختفي كلّياً عند الحالات النهائية (مكتمل/ملغى) فيذهب
    // معه المدخل الوحيد للمحادثة، وهي أحوج ما تكون بعد إغلاق الطلب.
    final hasAnyAction =
        o.status.nextAllowed.isNotEmpty || o.pharmacyTenantId != null;
    if (!hasAnyAction) return null;

    final cs = context.colors;
    final tk = context.tokens;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        child: AppButton(
          label: 'خيارات الطلب',
          icon: Icons.tune_outlined,
          loading: _busy,
          onPressed: _busy ? null : _showActionsSheet,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: context.text.bodySmall?.copyWith(color: tk.hint))),
        Text(value,
            style: context.text.bodyMedium?.copyWith(color: valueColor)),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: c),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

// ── توليد PDF فاتورة توريد رسمية (من منظور المستودع) ─────────────────────
double _whFreeUnitsOf(SupplyOrderItem i) => i.freeQuantity > 0
    ? i.freeQuantity
    : i.quantity * ((i.bonusPercentage ?? 0) / 100);

Future<Uint8List> _whBuildOrderPdf(
  SupplyOrderDetail order,
  List<StatusHistoryItem> history,
  double total,
  double freeUnits,
) async {
  final base = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document();

  const brand = PdfColor.fromInt(0xFF042623);
  const brandLight = PdfColor.fromInt(0xFFE2EDEB);
  const rowAlt = PdfColor.fromInt(0xFFF4F7F7);
  const grey = PdfColors.grey700;

  final currency = order.currency;
  final currencyTag = currencySymbol(currency);
  final dateStr = order.createdOn.toLocal().toString().split(' ').first;

  double totalBonus = 0;
  for (final i in order.items) {
    if (i.agreedUnitPrice == null) continue;
    totalBonus += _whFreeUnitsOf(i) * i.agreedUnitPrice!;
  }
  final netAmount = total - totalBonus;

  doc.addPage(
    pw.MultiPage(
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: base, bold: bold),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (ctx) => [
        // ── رأس الفاتورة ──────────────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(order.warehouseName,
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: brand)),
                  pw.SizedBox(height: 2),
                  pw.Text('فاتورة توريد رسمية',
                      style: pw.TextStyle(fontSize: 13, color: brand)),
                  if (order.warehouseCity.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('مدينة ${order.warehouseCity}',
                        style: const pw.TextStyle(fontSize: 11, color: grey)),
                  ],
                  if (order.warehousePhone.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(order.warehousePhone,
                        style: const pw.TextStyle(fontSize: 11, color: grey)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: brand,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text('توريد',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Divider(color: brand, thickness: 1.5),
        pw.SizedBox(height: 8),

        // ── بيانات الطلبية والعميل ────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _whPdfMeta('العميل', order.pharmacyName ?? '—', base, bold),
                  pw.SizedBox(height: 4),
                  if ((order.pharmacyCity ?? '').isNotEmpty)
                    _whPdfMeta('المدينة', order.pharmacyCity!, base, bold),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _whPdfMeta('رقم الطلبية', order.orderNumber, base, bold),
                pw.SizedBox(height: 4),
                _whPdfMeta('التاريخ', dateStr, base, bold),
                pw.SizedBox(height: 4),
                _whPdfMeta('العملة', currencyTag, base, bold),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 14),

        // ── جدول الأصناف ─────────────────────────────────────────────────
        pw.TableHelper.fromTextArray(
          headers: [
            '#',
            'الصنف',
            'السعر ($currencyTag)',
            'العدد',
            'الإجمالي ($currencyTag)',
            'البونص ($currencyTag)',
          ],
          data: order.items.asMap().entries.map((e) {
            final idx = e.key + 1;
            final i = e.value;
            final lineTotal = (i.agreedUnitPrice ?? 0) * i.quantity;
            final bonusVal = i.agreedUnitPrice == null
                ? 0.0
                : _whFreeUnitsOf(i) * i.agreedUnitPrice!;
            return [
              '$idx',
              i.medicineName,
              i.agreedUnitPrice == null
                  ? '—'
                  : formatAmount(i.agreedUnitPrice!, currency),
              formatQuantity(i.quantity),
              i.agreedUnitPrice == null ? '—' : formatAmount(lineTotal, currency),
              bonusVal > 0 ? formatAmount(bonusVal, currency) : '0',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: brand),
          cellAlignment: pw.Alignment.center,
          cellStyle: const pw.TextStyle(fontSize: 10),
          oddRowDecoration: const pw.BoxDecoration(color: rowAlt),
          border: pw.TableBorder.all(color: brandLight, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FixedColumnWidth(38),
            4: const pw.FlexColumnWidth(1.4),
            5: const pw.FlexColumnWidth(1.2),
          },
        ),

        // صف المجموع الكلي
        pw.Container(
          decoration: const pw.BoxDecoration(color: brandLight),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text('المجموع الكلي',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11),
                    textAlign: pw.TextAlign.right),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 1,
                child: pw.Text(formatAmount(total, currency),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                    totalBonus > 0 ? formatAmount(totalBonus, currency) : '0',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11),
                    textAlign: pw.TextAlign.center),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // ── ملخص المبالغ + ملاحظات ────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: brandLight, width: 1),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('ملاحظات:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(height: 6),
                    pw.Text('- الأسعار شاملة الضريبة.',
                        style: const pw.TextStyle(fontSize: 10, color: grey)),
                    pw.Text('- يُمنع إعادة الصرف إلا بموافقة خطية.',
                        style: const pw.TextStyle(fontSize: 10, color: grey)),
                    pw.Text(
                        '- يُرجى التأكد من مطابقة الأصناف عند الاستلام.',
                        style: const pw.TextStyle(fontSize: 10, color: grey)),
                    if (order.notes != null && order.notes!.isNotEmpty)
                      pw.Text('- ${order.notes}',
                          style: const pw.TextStyle(fontSize: 10, color: grey)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: brandLight, width: 1),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    _whSummaryRow('إجمالي الأصناف',
                        formatMoneyWith(total, currency), base, bold),
                    pw.Divider(color: brandLight, thickness: 0.5),
                    _whSummaryRow('إجمالي الحسم', '0', base, bold),
                    pw.Divider(color: brandLight, thickness: 0.5),
                    _whSummaryRow(
                        'إجمالي البونص',
                        totalBonus > 0
                            ? formatMoneyWith(totalBonus, currency)
                            : '0',
                        base,
                        bold),
                    pw.Divider(color: brand, thickness: 1),
                    _whSummaryRow('المبلغ المستحق',
                        formatMoneyWith(netAmount, currency), base, bold,
                        isHeader: true),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 18),

        // ── سجل حالات الطلبية ────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          pw.Text('سجل حالات الطلبية',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: brand)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['الحالة السابقة', 'الحالة الجديدة', 'بواسطة', 'التاريخ'],
            data: history
                .map((h) => [
                      h.oldStatus.label,
                      h.newStatus.label,
                      h.changedByName,
                      h.changedAt.toLocal().toString().substring(0, 16),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: brand),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: brandLight, width: 0.5),
          ),
          pw.SizedBox(height: 18),
        ],

        // ── توقيعات ───────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('مستلم الصيدلية',
                    style: const pw.TextStyle(fontSize: 11, color: grey)),
                pw.SizedBox(height: 20),
                pw.Container(width: 100, height: 1, color: grey),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('مندوب التسليم',
                    style: const pw.TextStyle(fontSize: 11, color: grey)),
                pw.SizedBox(height: 20),
                pw.Container(width: 100, height: 1, color: grey),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // ── تذييل ─────────────────────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            color: brandLight,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'تم عبر منصة توريد الإلكترونية',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: brand),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _whPdfMeta(
    String label, String value, pw.Font base, pw.Font bold) {
  return pw.RichText(
    text: pw.TextSpan(children: [
      pw.TextSpan(
          text: '$label:  ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 11)),
    ]),
  );
}

pw.Widget _whSummaryRow(String label, String value, pw.Font base, pw.Font bold,
    {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              fontSize: isHeader ? 11 : 10,
              fontWeight:
                  isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader
                  ? const PdfColor.fromInt(0xFF042623)
                  : PdfColors.grey700,
            )),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: isHeader ? 12 : 10,
              fontWeight:
                  isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            )),
      ],
    ),
  );
}
