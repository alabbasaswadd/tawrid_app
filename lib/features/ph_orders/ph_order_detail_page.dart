import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/contact_launcher.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

import 'ph_orders_page.dart' show orderTone;

// المسار الكامل للطلبية بالترتيب الذي يمرّ به فعلاً. «ملغاة» ليست محطة في
// المسار بل خروج منه، فلا تظهر في الخط الزمني.
const _orderJourney = <SupplyOrderStatus>[
  SupplyOrderStatus.pending,
  SupplyOrderStatus.confirmed,
  SupplyOrderStatus.processing,
  SupplyOrderStatus.shipped,
  SupplyOrderStatus.delivered,
  SupplyOrderStatus.completed,
];

String _journeyHint(SupplyOrderStatus s) => switch (s) {
      SupplyOrderStatus.pending => 'بانتظار أن يؤكّد المستودع الطلبية',
      SupplyOrderStatus.confirmed => 'أكّد المستودع الطلبية',
      SupplyOrderStatus.processing => 'يجري تجهيز الأصناف',
      SupplyOrderStatus.shipped => 'الشحنة في الطريق إليك',
      SupplyOrderStatus.delivered => 'بانتظار استلام الصيدلية',
      SupplyOrderStatus.completed => 'يُغلق الطلب وتُتاح فاتورة الشراء',
      SupplyOrderStatus.cancelled => 'أُلغيت الطلبية',
    };

// تفاصيل الطلبية للصيدلي (Figma: الصيدلي / تفاصيل الطلب).
class PhOrderDetailPage extends ConsumerStatefulWidget {
  const PhOrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<PhOrderDetailPage> createState() => _PhOrderDetailPageState();
}

class _PhOrderDetailPageState extends ConsumerState<PhOrderDetailPage> {
  SupplyOrderDetail? _order;
  List<StatusHistoryItem> _history = const [];
  bool _loading = true;
  bool _busy = false;
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
      final repo = ref.read(supplyOrderRepositoryProvider);
      final order = await repo.getOrderById(widget.orderId);
      // سجلّ الحالات تفصيل مساعد: فشله لا يمنع عرض الطلبية نفسها.
      List<StatusHistoryItem> history;
      try {
        history = await repo.getOrderHistory(widget.orderId);
      } catch (_) {
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

  double get _total {
    final items = _order?.items ?? const <SupplyOrderItem>[];
    return items.fold<double>(
        0, (sum, i) => sum + (i.agreedUnitPrice ?? 0) * i.quantity);
  }

  // الكميات المجانية: البونص نسبةً من الكمية المطلوبة لكل صنف.
  double get _freeUnits {
    final items = _order?.items ?? const <SupplyOrderItem>[];
    return items.fold<double>(
        0, (sum, i) => sum + i.quantity * ((i.bonusPercentage ?? 0) / 100));
  }

  /// متى بلغت الطلبية هذه الحالة، إن سجّلها الخادم.
  DateTime? _reachedAt(SupplyOrderStatus s) {
    final order = _order;
    if (order == null) return null;
    if (s == SupplyOrderStatus.pending) return order.createdOn;
    for (final h in _history) {
      if (h.newStatus == s) return h.changedAt;
    }
    return null;
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلبية'),
        content: const Text('سيُبلَّغ المستودع بالإلغاء، ولا يمكن التراجع عنه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الطلبية'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(supplyOrderRepositoryProvider).cancelOrder(widget.orderId);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُلغيت الطلبية');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // تُولَّد مرة واحدة فقط ومن طلبية مكتملة — الخادم يفرضها ونعكسها هنا.
  Future<void> _generateInvoice() async {
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(supplyOrderRepositoryProvider).generateInvoice(widget.orderId);
      if (!mounted) return;
      AppSnackbar.success(context, res.message);
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf() async {
    final order = _order;
    if (order == null) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _buildOrderPdf(order, _history, _total, _freeUnits);
      await Printing.sharePdf(
          bytes: bytes, filename: 'طلبية-${order.orderNumber}.pdf');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'تفاصيل الطلب',
        trailing: IconButton(
          tooltip: 'مشاركة كملف PDF',
          onPressed: _loading || _sharing ? null : _sharePdf,
          icon: _sharing
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share, size: 20),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _order == null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final order = _order!;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        _HeaderCard(order: order),

        const SizedBox(height: AppSpacing.md),
        AppCard(child: _Journey(order: order, reachedAt: _reachedAt)),

        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.medicineName} '
                          '(${item.quantity.toStringAsFixed(0)} ${item.unit}'
                          '${(item.bonusPercentage ?? 0) > 0 ? ' + ${(item.quantity * item.bonusPercentage! / 100).toStringAsFixed(0)} بونص' : ''})',
                          style: context.text.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        item.agreedUnitPrice == null
                            ? '—'
                            : formatMoneyWith(
                                item.agreedUnitPrice! * item.quantity, kPlatformCurrency),
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (_freeUnits > 0) ...[
                Divider(color: context.colors.outline),
                Row(
                  children: [
                    Expanded(
                        child: Text('كميات مجانية',
                            style: context.text.bodySmall?.copyWith(color: tk.hint))),
                    Text('${_freeUnits.toStringAsFixed(0)} عبوة',
                        style: context.text.titleSmall
                            ?.copyWith(color: tk.goldStrong)),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Divider(color: context.colors.outline),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(child: Text('الإجمالي', style: context.text.titleSmall)),
                  Text(formatMoneyWith(_total, kPlatformCurrency),
                      style: context.priceBrandStyle),
                ],
              ),
            ],
          ),
        ),

        if (_history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجلّ التغييرات', style: context.text.titleSmall),
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

        const SizedBox(height: AppSpacing.md),
        Text(
          'يُتاح توليد فاتورة الشراء بعد اكتمال الطلب ومرة واحدة فقط، '
          'ويمكنك إلغاء الطلب ما دام بانتظار التأكيد فقط.',
          style: context.text.labelSmall?.copyWith(color: tk.hint),
        ),
      ],
    );
  }

  // التواصل عبر واتساب لا باتصال: المحادثة تترك أثراً مكتوباً للطرفين،
  // وهو ما يحتاجه خلافٌ على طلبية. يظهر الزر فقط إن كان الرقم صالحاً.
  Future<void> _contactWarehouse() async {
    final order = _order!;
    final opened = await openWhatsApp(
      order.warehousePhone,
      message: 'مرحباً، بخصوص طلبية التوريد رقم ${order.orderNumber}',
    );
    if (!opened && mounted) {
      AppSnackbar.error(context, 'تعذّر فتح واتساب — تحقّق من رقم المستودع');
    }
  }

  // الشريط السفلي (Figma): التواصل مع المستودع + فاتورة الشراء، ويُضاف
  // «إلغاء الطلبية» ما دامت بانتظار التأكيد — وهي الحالة الوحيدة التي
  // يقبل الخادم الإلغاء فيها.
  Widget _buildBottomBar() {
    final cs = context.colors;
    final tk = context.tokens;
    final order = _order!;
    final canCancel = order.status == SupplyOrderStatus.pending;
    final canInvoice =
        order.status == SupplyOrderStatus.completed && !order.invoiceCreated;
    final canContact = whatsAppNumber(order.warehousePhone) != null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
        // خانتان ثابتتان: التواصل دائماً، والخانة الثانية تتبدّل مع مسار
        // الطلبية — «إلغاء الطلبية» ما دامت بانتظار التأكيد (وهي الحالة
        // الوحيدة التي يقبل الخادم الإلغاء فيها)، فإذا أكّدها المستودع
        // سقط الإلغاء وحلّت محلّه «فاتورة الشراء».
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'تواصل مع المستودع',
                icon: Icons.chat,
                // الرقم غير صالح ⇒ الزر معطَّل بدل أن يفتح واتساب على
                // رقم مشوَّه.
                onPressed: canContact ? _contactWarehouse : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: canCancel
                  ? AppButton(
                      label: 'إلغاء الطلبية',
                      variant: AppButtonVariant.danger,
                      loading: _busy,
                      onPressed: _busy ? null : _cancel,
                    )
                  : AppButton(
                      label: order.invoiceCreated
                          ? 'الفاتورة مُولَّدة'
                          : 'فاتورة الشراء',
                      variant: AppButtonVariant.outline,
                      loading: _busy && canInvoice,
                      onPressed: canInvoice && !_busy ? _generateInvoice : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// بطاقة رأس الطلبية (Figma): الرقم والحالة، المستودع، حالة التوصيل،
// التسليم المتوقع، وملاحظاتك.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});
  final SupplyOrderDetail order;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('طلب رقم ${order.orderNumber}',
                    style: context.text.titleLarge),
              ),
              StatusBadge(label: order.status.label, tone: orderTone(order.status)),
            ],
          ),
          const SizedBox(height: 10),
          _MetaLine(
            icon: AppIcons.warehouse,
            text: '${order.warehouseName} — ${order.warehouseCity}',
            color: cs.primary,
          ),
          const SizedBox(height: 6),
          _MetaLine(icon: AppIcons.truck, text: _journeyHint(order.status)),
          if (order.expectedDeliveryDate != null) ...[
            const SizedBox(height: 6),
            _MetaLine(
              icon: AppIcons.calendar,
              text:
                  'التسليم المتوقع: ${formatSmartTimestamp(order.expectedDeliveryDate!)}',
            ),
          ],
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _MetaLine(icon: AppIcons.fileText, text: 'ملاحظاتك: ${order.notes}'),
          ],
        ],
      ),
    );
  }
}

// الخط الزمني للطلبية (Figma) — المحطات المنقضية بعلامة صح، والحالية
// مملوءة، والقادمة برقمها فقط.
class _Journey extends StatelessWidget {
  const _Journey({required this.order, required this.reachedAt});

  final SupplyOrderDetail order;
  final DateTime? Function(SupplyOrderStatus) reachedAt;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    if (order.status == SupplyOrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_outlined, color: cs.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('أُلغيت هذه الطلبية ولم تكتمل.',
                style: context.text.bodyMedium?.copyWith(color: cs.error)),
          ),
        ],
      );
    }

    final currentIndex = _orderJourney.indexOf(order.status);

    return Column(
      children: [
        for (final (i, step) in _orderJourney.indexed)
          IntrinsicHeight(
            // العمود البصري أولاً: في RTL يُرسم أول أبناء الصف في اليمين،
            // فيأتي خطّ المحطات على يمين النص كما يُقرأ العربي.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentIndex ? cs.primary : cs.surface,
                        border: Border.all(
                          color: i <= currentIndex ? cs.primary : cs.outline,
                        ),
                      ),
                      child: Center(
                        child: i <= currentIndex
                            ? Icon(
                                i == currentIndex
                                    ? Icons.local_shipping_outlined
                                    : Icons.check,
                                size: 15,
                                color: cs.onPrimary,
                              )
                            : Text('${i + 1}',
                                style: context.text.labelSmall
                                    ?.copyWith(color: tk.hint)),
                      ),
                    ),
                    if (i < _orderJourney.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: i < currentIndex ? cs.primary : cs.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: i <= currentIndex
                              ? context.text.titleSmall?.copyWith(
                                  color: i == currentIndex ? cs.primary : null)
                              : context.text.titleSmall?.copyWith(color: tk.hint),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          switch (reachedAt(step)) {
                            final DateTime t => formatSmartTimestamp(t),
                            _ => _journeyHint(step),
                          },
                          style: context.text.bodySmall?.copyWith(color: tk.hint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.color});
  final AppIcons icon;
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
          child: AppIcon(icon, size: 15, color: c),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

// ── توليد PDF للطلبية (عربي RTL بخط Cairo) ───────────────────────────
Future<Uint8List> _buildOrderPdf(
  SupplyOrderDetail order,
  List<StatusHistoryItem> history,
  double total,
  double freeUnits,
) async {
  final base = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document();

  final rows = order.items
      .map((i) => [
            i.medicineName,
            '${i.quantity.toStringAsFixed(0)} ${i.unit}',
            i.agreedUnitPrice == null ? '—' : formatMoney(i.agreedUnitPrice!),
            (i.bonusPercentage ?? 0) > 0
                ? '${i.bonusPercentage!.toStringAsFixed(0)}%'
                : '—',
            i.agreedUnitPrice == null
                ? '—'
                : formatMoney(i.agreedUnitPrice! * i.quantity),
          ])
      .toList();

  doc.addPage(pw.MultiPage(
    textDirection: pw.TextDirection.rtl,
    theme: pw.ThemeData.withFont(base: base, bold: bold),
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      pw.Text('طلبية توريد رقم ${order.orderNumber}',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('الحالة: ${order.status.label}'),
      pw.Text('المستودع: ${order.warehouseName} — ${order.warehouseCity}'
          ' · ${order.warehousePhone}'),
      pw.Text('تاريخ الإنشاء: ${order.createdOn.toLocal().toString().split(' ').first}'),
      if (order.expectedDeliveryDate != null)
        pw.Text('التسليم المتوقع: '
            '${order.expectedDeliveryDate!.toLocal().toString().split(' ').first}'),
      if (order.notes != null && order.notes!.isNotEmpty)
        pw.Text('ملاحظات: ${order.notes}'),

      pw.SizedBox(height: 14),
      pw.Text('الأصناف',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['الدواء', 'الكمية', 'سعر الوحدة', 'البونص', 'الإجمالي'],
        data: rows,
        headerStyle:
            pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF086653)),
        cellAlignment: pw.Alignment.centerRight,
        cellStyle: const pw.TextStyle(fontSize: 10),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F3F5)),
      ),

      pw.SizedBox(height: 10),
      if (freeUnits > 0)
        pw.Text('كميات مجانية (بونص): ${freeUnits.toStringAsFixed(0)} عبوة'),
      pw.Text(
        'الإجمالي: ${formatMoneyWith(total, kPlatformCurrency)}',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text('الإجمالي لا يشمل قيمة البونص — البونص يُسلَّم عيناً لا حسماً.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),

      if (history.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text('مسار الطلبية',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final h in history)
          pw.Text(
            '${h.oldStatus.label} ← ${h.newStatus.label} · ${h.changedByName} · '
            '${h.changedAt.toLocal().toString().split('.').first}',
            style: const pw.TextStyle(fontSize: 10),
          ),
      ],

      pw.SizedBox(height: 16),
      pw.Text('توريد — منصة التوريد الدوائي',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
    ],
  ));

  return doc.save();
}
