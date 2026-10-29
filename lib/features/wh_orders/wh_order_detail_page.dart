import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  double get _freeUnits {
    final items = _order?.items ?? const <SupplyOrderItem>[];
    return items.fold<double>(
        0, (sum, i) => sum + i.quantity * ((i.bonusPercentage ?? 0) / 100));
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

  Future<void> _contactPharmacy() async {
    final phone = _order?.pharmacyPhone;
    final opened = await openWhatsApp(
      phone,
      message: 'مرحباً، بخصوص طلب التوريد رقم ${_order!.orderNumber}',
    );
    if (!opened && mounted) {
      AppSnackbar.error(context, 'تعذّر فتح واتساب — تحقّق من رقم الصيدلية');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContact =
        _order != null && whatsAppNumber(_order!.pharmacyPhone) != null;

    return Scaffold(
      appBar: InnerTopBar(
        title: 'تفاصيل الطلب',
        trailing: canContact
            ? IconButton(
                tooltip: 'تواصل مع الصيدلية',
                icon: const Icon(Icons.chat, size: 20),
                onPressed: _contactPharmacy,
              )
            : null,
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
                            item.agreedUnitPrice! * item.quantity,
                            kPlatformCurrency),
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
                  value: formatMoneyWith(_itemsTotal, kPlatformCurrency)),
              if (_freeUnits > 0) ...[
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'كميات مجانية (بونص)',
                  value: '${_freeUnits.toStringAsFixed(0)} عبوة',
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
                  Text(formatMoneyWith(_itemsTotal, kPlatformCurrency),
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

  // الإجراءات تُبنى من `nextAllowed` — نفس انتقالات الخادم، فلا يظهر زرّ
  // يُرفض. لا يوجد «تعديل الكميات» في التصميم هنا لأن الخادم لا يتيحه:
  // يُعدَّل الطلب بالتفاهم مع الصيدلية ثم يُرفض ويُعاد إنشاؤه.
  Widget? _buildActions() {
    final o = _order!;
    final next = o.status.nextAllowed;
    if (next.isEmpty) return null;

    final cs = context.colors;
    final tk = context.tokens;
    final forward =
        next.where((s) => s != SupplyOrderStatus.cancelled).toList();
    final canReject = next.contains(SupplyOrderStatus.cancelled);

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
        child: Row(
          children: [
            if (canReject)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _move(SupplyOrderStatus.cancelled,
                        confirmText:
                            'سيُبلَّغ الصيدلية برفض الطلب، ولا يمكن التراجع عنه.'),
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: const Text('رفض'),
              ),
            if (canReject) const SizedBox(width: AppSpacing.sm),
            if (forward.isNotEmpty)
              Expanded(
                child: AppButton(
                  label: switch (forward.first) {
                    SupplyOrderStatus.confirmed => 'قبول الطلب',
                    SupplyOrderStatus.processing => 'بدء التجهيز',
                    SupplyOrderStatus.shipped => 'تأكيد الشحن',
                    SupplyOrderStatus.delivered => 'تأكيد التسليم',
                    SupplyOrderStatus.completed => 'إغلاق الطلب',
                    _ => forward.first.label,
                  },
                  loading: _busy,
                  onPressed: _busy ? null : () => _move(forward.first),
                ),
              ),
          ],
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
