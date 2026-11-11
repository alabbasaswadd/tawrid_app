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
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// سطر في لوح طلبات التسعير: إمّا طلب مفتوح لم أُسعّره، وإمّا عرض سعر
/// قدّمتُه على طلب.
///
/// الخادم يفصلهما في نقطتين (`open` تستبعد ما سعّرته، و`my-quotations`
/// تُرجع ما سعّرت)، لكن المستودع يراهما عملاً واحداً: ما ينتظرني وما
/// قدّمته. الدمج هنا لا في الخادم.
class _BoardEntry {
  _BoardEntry.open(TenderSummary t)
      : requestId = t.id,
        title = t.title,
        itemCount = t.itemCount,
        expiresAt = t.expiresAt,
        isExpired = t.isExpired,
        area = [t.tenantGovernorate, t.tenantCity]
            .where((s) => s != null && s.isNotEmpty)
            .join(' — '),
        quotedType = null,
        quotationCount = t.offerCount,
        isWinner = false;

  _BoardEntry.quoted(MyTenderOfferSummary q)
      : requestId = q.tenderId,
        title = q.tenderTitle,
        itemCount = 0,
        expiresAt = q.tenderExpiresAt,
        isExpired = DateTime.now().isAfter(q.tenderExpiresAt),
        area = '',
        quotedType = q.offerType,
        quotationCount = 0,
        isWinner = q.isSelectedByPharmacy;

  final String requestId;
  final String title;
  final int itemCount;
  final DateTime expiresAt;
  final bool isExpired;
  final String area;

  /// غير null ⇒ قدّمتُ عرضاً على هذا الطلب.
  final TenderOfferType? quotedType;
  final int quotationCount;
  final bool isWinner;

  bool get hasQuoted => quotedType != null;

  /// «يُغلق قريباً» = ٤٨ ساعة أو أقل — العتبة التي تستحقّ قراراً اليوم.
  bool get closingSoon =>
      !isExpired && expiresAt.difference(DateTime.now()).inHours <= 48;
}

enum _BoardTab {
  all('الكل'),
  quoted('قدّمت عرضاً'),
  closingSoon('تُغلق قريباً');

  const _BoardTab(this.label);
  final String label;

  bool matches(_BoardEntry e) => switch (this) {
        _BoardTab.all => true,
        _BoardTab.quoted => e.hasQuoted,
        _BoardTab.closingSoon => e.closingSoon && !e.hasQuoted,
      };
}

// لوح طلبات التسعير للمستودع (Figma: المستودع / طلبات التسعير).
//
// لوح تصفّح لا صندوق وارد: الخادم يعرض الطلبات المطابقة لمناطق تغطية
// المستودع فقط، والاطلاع والردّ اختياريان.
class WhTendersPage extends ConsumerStatefulWidget {
  const WhTendersPage({super.key});

  @override
  ConsumerState<WhTendersPage> createState() => _WhTendersPageState();
}

class _WhTendersPageState extends ConsumerState<WhTendersPage> {
  List<_BoardEntry>? _entries;
  bool _loading = true;
  String? _error;
  _BoardTab _tab = _BoardTab.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(tenderRepositoryProvider);
      final open = await repo.getOpenTenders(limit: 50);

      // عروضي المقدَّمة تفصيل مكمّل: فشلها يترك اللوح يعرض المفتوحة.
      List<MyTenderOfferSummary> mine;
      try {
        mine = await repo.getMyOffers(limit: 50);
      } catch (_) {
        mine = const [];
      }

      if (!mounted) return;
      setState(() {
        _entries = [
          ...open.map(_BoardEntry.open),
          ...mine.map(_BoardEntry.quoted),
        ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
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

  Future<void> _openSubmit(_BoardEntry e) async {
    await context.push(TRoutes.whSubmitTenderOffer(e.requestId));
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'طلبات التسعير',
        trailing: IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'تحديث',
          onPressed: _loading ? null : _load,
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _entries ?? const <_BoardEntry>[];
    final shown = all.where(_tab.matches).toList();
    final tk = context.tokens;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
          child: Row(
            children: [
              for (final t in _BoardTab.values)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: AppFilterChip(
                    label: t.label,
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${shown.length} ${shown.length == 1 ? 'طلب تسعير منشور' : 'طلب تسعير منشوراً'}'
                ' ضمن مناطق تغطيتك',
                style: context.text.bodySmall?.copyWith(color: tk.hint),
              ),
              const SizedBox(height: 2),
              // قاعدة الخادم مكتوبة صراحةً: لا يرى المستودع إلا ما يغطّيه،
              // والردّ اختياري — فلا يظنّ القائمة ناقصة ولا الردّ إلزامياً.
              Text(
                'تُعرض الطلبات المطابقة لمناطق تغطيتك فقط — الاطلاع والردّ اختياريان',
                style: context.text.labelSmall?.copyWith(color: tk.hint),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        Expanded(
          child: shown.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.request_quote_outlined,
                      message: switch (_tab) {
                        _BoardTab.all =>
                          'لا طلبات تسعير منشورة ضمن مناطق تغطيتك حالياً',
                        _BoardTab.quoted => 'لم تقدّم أي عرض سعر بعد',
                        _BoardTab.closingSoon => 'لا طلبات تُغلق قريباً',
                      },
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, AppSpacing.x3l),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => _card(shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(_BoardEntry e) {
    final quoted = e.hasQuoted;

    final (label, tone) = switch (e) {
      _ when e.isWinner => ('فائز', StatusTone.success),
      _ when quoted => ('قدّمت عرضاً', StatusTone.brand),
      _ when e.isExpired => ('مغلق', StatusTone.neutral),
      _ when e.closingSoon => ('يُغلق قريباً', StatusTone.warning),
      _ => ('مفتوح', StatusTone.success),
    };

    return TenderCard(
      title: e.title,
      itemsText: quoted
          ? 'عرضك: ${e.quotedType!.label}${e.isWinner ? ' — فزت بالطلب' : ''}'
          : '${e.itemCount} ${e.itemCount == 1 ? 'صنف' : 'أصناف'} · كميات محددة',
      deadlineText: e.isExpired
          ? 'أُغلق ${formatSmartTimestamp(e.expiresAt)}'
          : 'يُغلق ${formatSmartTimestamp(e.expiresAt)}',
      deliveryText: e.area.isEmpty ? 'ضمن مناطق تغطيتك' : 'التسليم: ${e.area}',
      statusLabel: label,
      statusTone: tone,
      offersCountLabel: !quoted && e.quotationCount > 0
          ? 'قدّم ${e.quotationCount} '
              '${e.quotationCount == 1 ? 'مستودع عرضه' : 'مستودعات عروضها'}'
          : null,
      // النصّ يتبع ما يمكن فعله فعلاً: الخادم يرفض التسعير بعد الإغلاق.
      compareLabel: e.isExpired
          ? 'انتهت المهلة'
          : quoted
              ? 'تعديل عرضك قبل الإغلاق'
              : 'تقديم عرض سعر',
      onCompare: e.isExpired ? null : () => _openSubmit(e),
      onTap: e.isExpired ? null : () => _openSubmit(e),
    );
  }
}
