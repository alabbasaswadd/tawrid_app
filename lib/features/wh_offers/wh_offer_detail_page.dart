import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/chat_sheet.dart';

double _netUnitPrice(SalesOfferItem i) =>
    i.unitPrice * (1 - (i.discountPercentage ?? 0) / 100);

// تفاصيل العرض عند المستودع (Figma: المستودع / تفاصيل العرض).
//
// تختلف عن تفاصيل العرض عند الصيدلي: هذه شاشة مالكٍ يُراجع ما نشره —
// المناطق المستهدفة، شروط الدفع، وتعليقات الصيدليات وأسئلتها — لا شاشة
// شراء. ولا زرّ «إضافة للطلبية» فيها بطبيعة الحال.
class WhOfferDetailPage extends ConsumerStatefulWidget {
  const WhOfferDetailPage({required this.offerId, super.key});

  final String offerId;

  @override
  ConsumerState<WhOfferDetailPage> createState() => _WhOfferDetailPageState();
}

class _WhOfferDetailPageState extends ConsumerState<WhOfferDetailPage> {
  SalesOfferDetail? _offer;
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
      final offer = await ref.read(salesOfferRepositoryProvider).getWarehouseOfferById(widget.offerId);
      if (!mounted) return;
      setState(() {
        _offer = offer;
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

  void _openChat() {
    final repo = ref.read(salesOfferRepositoryProvider);
    ChatSheet.show(
      context,
      title: 'تعليقات العرض',
      currentUserType: 'warehouse',
      loadMessages: () => repo.getWarehouseComments(widget.offerId),
      sendMessage: (text) => repo.addWarehouseComment(widget.offerId, text),
    );
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await ref.read(salesOfferRepositoryProvider).publishOffer(widget.offerId);
      if (!mounted) return;
      AppSnackbar.success(context, 'نُشر العرض — صار مرئياً للصيدليات المستهدفة');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إيقاف العرض'),
        content:
            const Text('لن تراه الصيدليات بعد الإيقاف، ولا يمكن التراجع عنه.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إيقاف'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(salesOfferRepositoryProvider).cancelOffer(widget.offerId);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُوقف العرض');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'تفاصيل العرض',
        trailing: _offer == null
            ? null
            : IconButton(
                tooltip: 'التعليقات',
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                onPressed: _openChat,
              ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _offer == null ? null : _buildActions(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final o = _offer!;
    final tk = context.tokens;

    final (label, tone) = switch (o.status) {
      SalesOfferStatus.active => ('منشور', StatusTone.success),
      SalesOfferStatus.draft => ('مسودة', StatusTone.neutral),
      SalesOfferStatus.cancelled => ('متوقف', StatusTone.danger),
      SalesOfferStatus.expired => ('منتهٍ', StatusTone.neutral),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(o.title, style: context.text.titleLarge)),
                  StatusBadge(label: label, tone: tone),
                ],
              ),
              const SizedBox(height: 10),
              _Line(
                icon: Icons.event_outlined,
                text: o.expiresAt == null
                    // العرض الثابت: بدايةٌ بلا نهاية — فلا يُفتعَل له «إلى».
                    ? 'ساري من ${formatSmartTimestamp(o.startsAt)} — '
                        'عرض ثابت بلا تاريخ انتهاء'
                    : 'ساري من ${formatSmartTimestamp(o.startsAt)} '
                        'إلى ${formatSmartTimestamp(o.expiresAt!)}',
              ),
              const SizedBox(height: 6),
              _Line(
                icon: Icons.place_outlined,
                text: o.targetRegions.isEmpty
                    ? 'المناطق المستهدفة: كل مناطق خدمتك'
                    : 'المناطق المستهدفة: '
                        '${o.targetRegions.map((r) => r.label).join(' · ')}',
              ),
              const SizedBox(height: 6),
              _Line(
                icon: Icons.inventory_2_outlined,
                text: '${o.items.length} '
                    '${o.items.length == 1 ? 'صنف' : 'أصناف'} · '
                    'العملة: ${currencySymbol(o.currency)}',
              ),

              if (o.bonusMedicineName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tk.goldSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: tk.gold),
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.gift, size: 16, color: tk.goldStrong),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بونص العرض: '
                          '${o.bonusMedicineQuantity?.toStringAsFixed(0) ?? ''} '
                          '${o.bonusMedicineUnit ?? ''} '
                          '${o.bonusMedicineName} مجاناً',
                          style: context.text.bodySmall
                              ?.copyWith(color: tk.goldStrong),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              _Line(
                icon: Icons.link,
                text: o.isPublicInRegion
                    ? 'متاح لكل صيدليات المناطق المستهدفة'
                    : 'موجَّه لصيدليات محدَّدة فقط',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text('أصناف العرض', style: context.text.titleLarge),
        const SizedBox(height: AppSpacing.sm),

        for (final item in o.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.medicineName,
                                style: context.text.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              [
                                item.unit,
                                if ((item.discountPercentage ?? 0) > 0)
                                  'حسم ${item.discountPercentage!.toStringAsFixed(0)}٪'
                                else
                                  'بلا حسم',
                              ].join(' · '),
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('سعر الوحدة',
                              style: context.text.labelSmall
                                  ?.copyWith(color: tk.hint)),
                          Text(
                              formatMoneyWith(
                                  _netUnitPrice(item), o.currency),
                              style: context.text.titleSmall),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        item.quantity <= 0
                            ? 'الكمية في العرض: مفتوحة'
                            : 'الكمية في العرض: '
                                '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                        style:
                            context.text.labelSmall?.copyWith(color: tk.hint),
                      ),
                      const Spacer(),
                      if (item.hasBonus)
                        BonusBadge(
                          label:
                              item.bonusLabel!,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (o.upfrontPercentage != null ||
            o.paymentPeriodDays != null ||
            (o.consignmentTerms?.isNotEmpty ?? false)) ...[
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الشروط وشروط الدفع', style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  [
                    if (o.upfrontPercentage != null)
                      'دفعة مقدَّمة ${o.upfrontPercentage!.toStringAsFixed(0)}٪',
                    if (o.paymentPeriodDays != null)
                      'مهلة سداد ${o.paymentPeriodDays} يوماً',
                    if (o.consignmentTerms?.isNotEmpty ?? false)
                      o.consignmentTerms!,
                  ].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: tk.hint),
                ),
              ],
            ),
          ),
        ],

      ],
    );
  }

  // الإجراءات تتبع الحالة: المسودة تُنشر، والمنشور يُوقَف، وما انتهى أو
  // أُوقف لا إجراء عليه — فلا يظهر شريط أصلاً.
  Widget? _buildActions() {
    final o = _offer!;
    if (o.status == SalesOfferStatus.expired ||
        o.status == SalesOfferStatus.cancelled) {
      return null;
    }

    final cs = context.colors;
    final tk = context.tokens;
    final isDraft = o.status == SalesOfferStatus.draft;

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
            Expanded(
              flex: 3,
              child: AppButton(
                // الخادم لا يتيح تعديل عرض بعد إنشائه، فالزرّ الرئيسي هو
                // النشر للمسودة — ولا نَعِد بـ«تعديل العرض» كما في التصميم.
                label: isDraft ? 'نشر العرض' : 'العرض منشور',
                loading: _busy && isDraft,
                onPressed: isDraft && !_busy ? _publish : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'إيقاف العرض',
                variant: AppButtonVariant.danger,
                onPressed: _busy ? null : _stop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.onSurfaceVariant;
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
