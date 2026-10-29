import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

import 'ph_tenders_page.dart' show tenderTone;

/// حساب عرض سعر واحد مقابل أصناف الطلب — يُجمَّع مرة ويُعاد استخدامه في
/// الترتيب والشارات والعرض، بدل إعادة الحساب في كل موضع.
class _QuoteMath {
  _QuoteMath(this.quote, List<TenderItem> requestItems) {
    final wanted = {for (final i in requestItems) i.id: i.quantity};
    requestedCount = requestItems.length;

    var sum = 0.0;
    var bonusValue = 0.0;
    var priced = 0;

    for (final qi in quote.items) {
      final qty = wanted[qi.tenderItemId];
      if (qty == null) continue;
      covered++;
      final price = qi.unitPrice;
      if (price == null) continue;
      priced++;
      sum += price * qty;
      // البونص يُسلَّم عيناً، وقيمته تُحتسب هنا لمقارنة التكلفة الفعلية فقط.
      final bonusPct = qi.bonusPercentage ?? 0;
      bonusValue += price * qty * (bonusPct / 100);
      bonusValue += (qi.extraBonus ?? 0) * price;
    }

    total = priced > 0 ? sum : null;
    effective = total == null ? null : total! - bonusValue;
    hasBonus = bonusValue > 0;
  }

  final TenderOffer quote;
  late final int requestedCount;
  int covered = 0;

  /// الإجمالي قبل احتساب قيمة البونص — null إن لم يُسعَّر أي صنف.
  double? total;

  /// التكلفة الفعلية بعد خصم قيمة البونص عيناً.
  double? effective;
  bool hasBonus = false;

  bool get coversAll => covered >= requestedCount;
}

// مقارنة عروض الأسعار (Figma: الصيدلي / مقارنة عروض الأسعار).
//
// هذه الشاشة هي نقطة القرار: الصيدلي يقارن عروضاً متعدّدة ويعتمد واحداً،
// فتُرفض البقية وتُنشأ طلبية توريد تلقائياً. الخادم يحجب تفاصيل العروض حتى
// انتهاء المهلة، والواجهة تقول ذلك صراحةً بدل أن تعرض قائمة فارغة.
class PhCompareQuotationsPage extends ConsumerStatefulWidget {
  const PhCompareQuotationsPage({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<PhCompareQuotationsPage> createState() =>
      _PhCompareQuotationsPageState();
}

class _PhCompareQuotationsPageState
    extends ConsumerState<PhCompareQuotationsPage> {
  TenderDetail? _request;
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
      final t = await ref.read(tenderRepositoryProvider).getTenderById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = t;
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

  List<_QuoteMath> get _quotes {
    final t = _request;
    if (t == null) return const [];
    final list = (t.offers ?? const <TenderOffer>[])
        .map((q) => _QuoteMath(q, t.items))
        .toList();
    // الأرخص فعلياً أولاً — وما لم يُسعَّر يذهب إلى الذيل بدل أن يتصدّر بصفر.
    list.sort((a, b) {
      final ae = a.effective, be = b.effective;
      if (ae == null && be == null) return 0;
      if (ae == null) return 1;
      if (be == null) return -1;
      return ae.compareTo(be);
    });
    return list;
  }

  Future<void> _award(_QuoteMath m) async {
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتماد عرض السعر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'سيُعتمد عرض «${m.quote.warehouseName}»، وتُرفض بقية العروض، '
                'وتُنشأ طلبية توريد بحالة «بانتظار التأكيد».',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
                controller: notes, hint: 'ملاحظة للمستودع (اختياري)'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد')),
        ],
      ),
    );
    final winnerNotes = notes.text.trim();
    notes.dispose();
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final res = await ref.read(tenderRepositoryProvider).selectOffer(
            widget.requestId,
            m.quote.id,
            winnerNotes: winnerNotes.isEmpty ? null : winnerNotes,
          );
      if (!mounted) return;
      AppSnackbar.success(context, res.message);
      context.go(TRoutes.phOrders);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishDraft() async {
    setState(() => _busy = true);
    try {
      await ref.read(tenderRepositoryProvider).publishTender(widget.requestId);
      if (!mounted) return;
      AppSnackbar.success(context, 'نُشر الطلب — وصل المستودعات التي تخدم مدينتك');
      await _load();
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء طلب التسعير'),
        content: const Text(
            'لن تتمكن المستودعات من تقديم عروض أسعار بعد الإلغاء، ولا يمكن التراجع عنه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(tenderRepositoryProvider).cancelTender(widget.requestId);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُلغي طلب التسعير');
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
      appBar: const InnerTopBar(title: 'مقارنة عروض الأسعار'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final t = _request!;
    final tk = context.tokens;
    final quotes = _quotes;
    // الخادم يرفض الترسية قبل انتهاء المهلة وبعد الترسية أو الإلغاء.
    final canAward = t.offersVisible &&
        t.status != TenderStatus.awarded &&
        t.status != TenderStatus.cancelled &&
        t.status != TenderStatus.draft;
    final cheapestId = quotes.isNotEmpty && quotes.first.effective != null
        ? quotes.first.quote.id
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        // رأس الطلب على سطح باهت — سياقٌ لا بطاقة قرار.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tk.brandSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.title, style: context.text.titleMedium)),
                  StatusBadge(label: t.status.label, tone: tenderTone(t.status)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${t.items.length} ${t.items.length == 1 ? 'صنف' : 'أصناف'} · '
                '${t.offersVisible ? 'أُغلق ${formatSmartTimestamp(t.expiresAt)}' : 'يُغلق ${formatSmartTimestamp(t.expiresAt)}'} · '
                'وصلك ${t.offerCount} ${t.offerCount == 1 ? 'عرض سعر' : 'عروض أسعار'}',
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        if (t.status == TenderStatus.draft)
          _Notice(
            icon: Icons.edit_note,
            text: 'هذه مسودة لم تُنشر — لا يراها أي مستودع ولن تصلك عروض '
                'أسعار حتى تنشرها.',
          )
        else if (!t.offersVisible)
          _Notice(
            icon: Icons.lock_clock,
            text: 'الاختيار متاح بعد انتهاء مهلة الطلب فقط. وعند الاعتماد: '
                'يُقبل العرض الفائز، تُرفض بقية العروض، وتُنشأ طلبية توريد '
                'تلقائياً بحالة «بانتظار التأكيد».',
          )
        else if (canAward)
          _Notice(
            icon: Icons.gavel_outlined,
            text: 'عند اعتماد عرض: تُرفض بقية العروض وتُنشأ طلبية توريد '
                'تلقائياً بحالة «بانتظار التأكيد».',
          ),

        const SizedBox(height: AppSpacing.md),

        if (t.status == TenderStatus.draft) ...[
          AppButton(
            label: 'نشر طلب التسعير',
            loading: _busy,
            onPressed: _busy ? null : _publishDraft,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'حذف المسودة',
            variant: AppButtonVariant.danger,
            onPressed: _busy ? null : _cancel,
          ),
        ] else if (!t.offersVisible)
          AppCard(
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, size: 18, color: tk.hint),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    t.offerCount == 0
                        ? 'لم يصل أي عرض سعر بعد.'
                        : 'وصلك ${t.offerCount} عرض سعر — تُكشف تفاصيلها بعد '
                            'انتهاء المهلة حفاظاً على تكافؤ المنافسة.',
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                ),
              ],
            ),
          )
        else if (quotes.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            message: 'انتهت المهلة دون أن يصل أي عرض سعر على هذا الطلب',
          )
        else
          for (final m in quotes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _QuoteCard(
                math: m,
                requestItems: t.items,
                isCheapest: m.quote.id == cheapestId,
                canAward: canAward && !_busy,
                onAward: () => _award(m),
              ),
            ),

        if (t.winnerNotes != null && t.winnerNotes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملاحظات الترسية', style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(t.winnerNotes!, style: context.text.bodySmall),
              ],
            ),
          ),
        ],

        // `offersVisible` هو بالضبط «انتهت المهلة» كما يحسبه الخادم،
        // ونفيه أدقّ من مقارنة ساعة الجهاز بساعة الخادم.
        if (t.status == TenderStatus.open && !t.offersVisible) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'إلغاء طلب التسعير',
            variant: AppButtonVariant.danger,
            loading: _busy,
            onPressed: _busy ? null : _cancel,
          ),
        ],
      ],
    );
  }
}

// بطاقة عرض سعر في المقارنة (Figma): اسم المستودع وشارة التميّز، تغطية
// الأصناف، نوع التسعير، ثم الإجمالي والتكلفة الفعلية بعد البونص.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.math,
    required this.requestItems,
    required this.isCheapest,
    required this.canAward,
    required this.onAward,
  });

  final _QuoteMath math;
  final List<TenderItem> requestItems;
  final bool isCheapest;
  final bool canAward;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final q = math.quote;
    final selected = q.isSelectedByPharmacy;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected
              ? tk.success
              : isCheapest
                  ? tk.gold
                  : cs.outline,
        ),
        boxShadow: tk.cardShadow,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(q.warehouseName, style: context.text.titleMedium),
              ),
              if (selected)
                const StatusBadge(label: 'معتمد', tone: StatusTone.success)
              else if (q.status == TenderOfferStatus.rejected)
                const StatusBadge(label: 'مرفوض', tone: StatusTone.neutral)
              else if (isCheapest)
                const BonusBadge(label: 'أقل تكلفة فعلية', compact: true),
            ],
          ),
          const SizedBox(height: 10),

          _Meta(
            icon: AppIcons.package,
            text: math.coversAll
                ? 'كل الأصناف متوفرة'
                : '${math.covered} من ${math.requestedCount} أصناف متوفرة',
            color: math.coversAll ? tk.success : tk.warning,
          ),
          const SizedBox(height: 6),
          _Meta(
            icon: AppIcons.gift,
            text: switch (q.offerType) {
              TenderOfferType.priceBased => 'تسعير بالسعر، بلا بونص',
              TenderOfferType.bonusBased => 'تسعير بالبونص، بونص أصناف فقط',
              TenderOfferType.mixed => 'تسعير بالسعر مع بونص على الأصناف',
            },
            color: math.hasBonus ? tk.goldStrong : null,
          ),
          if (q.notes != null && q.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Meta(icon: AppIcons.fileText, text: q.notes!),
          ],

          const SizedBox(height: 10),
          Divider(color: cs.outline),
          const SizedBox(height: 10),

          if (math.total == null)
            Text('لم يُسعَّر هذا العرض — راجع تفاصيله مع المستودع',
                style: context.text.bodySmall?.copyWith(color: tk.hint))
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي: ${formatMoneyWith(math.total!, kPlatformCurrency)}',
                        style: context.text.bodySmall?.copyWith(color: tk.hint),
                      ),
                      if (math.hasBonus)
                        Text(
                          'الفعلي بعد البونص: '
                          '${formatMoneyWith(math.effective!, kPlatformCurrency)}',
                          style: context.priceBrandStyle,
                        ),
                    ],
                  ),
                ),
              ],
            ),

          if (canAward && !selected) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'اعتماد هذا العرض',
              variant: AppButtonVariant.outline,
              onPressed: onAward,
            ),
          ],
        ],
      ),
    );
  }
}

// لوحة تنبيه ذهبية — قواعد الاختيار والترسية مكتوبة لا مُفترَضة.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tk.goldSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tk.gold),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tk.goldStrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: context.text.bodySmall?.copyWith(color: tk.goldStrong)),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
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
          child: AppIcon(icon, size: 14, color: c),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}
