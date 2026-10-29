import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/comments_sheet.dart';

// شرائح عروض المستودع (Figma): الكل، منشور، مسودة، متوقف، منتهٍ.
enum _OffersTab {
  all('الكل'),
  published('منشور'),
  draft('مسودة'),
  stopped('متوقف'),
  expired('منتهٍ');

  const _OffersTab(this.label);
  final String label;

  bool matches(SalesOfferStatus s) => switch (this) {
        _OffersTab.all => true,
        _OffersTab.published => s == SalesOfferStatus.active,
        _OffersTab.draft => s == SalesOfferStatus.draft,
        _OffersTab.stopped => s == SalesOfferStatus.cancelled,
        _OffersTab.expired => s == SalesOfferStatus.expired,
      };
}

// عروضي عند المستودع (Figma: المستودع / العروض).
//
// شاشة إدارة لا تصفّح: لكل عرض حالته وإجراءاه، والسطر العلوي ينبّه إلى
// ما يقارب على الانتهاء قبل أن ينتهي صامتاً.
class WhOffersPage extends ConsumerStatefulWidget {
  const WhOffersPage({super.key});

  @override
  ConsumerState<WhOffersPage> createState() => _WhOffersPageState();
}

class _WhOffersPageState extends ConsumerState<WhOffersPage> {
  List<SalesOfferSummary>? _offers;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  _OffersTab _tab = _OffersTab.all;

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
      final list =
          await ref.read(salesOfferRepositoryProvider).getMyOffers(limit: 50);
      if (!mounted) return;
      setState(() {
        _offers = list;
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

  List<SalesOfferSummary> get _active => (_offers ?? const [])
      .where((o) => o.status == SalesOfferStatus.active)
      .toList();

  List<SalesOfferSummary> get _expiringSoon => _active.where((o) {
        final days = o.expiresAt.difference(DateTime.now()).inDays;
        return days >= 0 && days <= 3;
      }).toList();

  Future<void> _publish(SalesOfferSummary offer) async {
    setState(() => _busy = true);
    try {
      await ref.read(salesOfferRepositoryProvider).publishOffer(offer.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'نُشر العرض');
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(SalesOfferSummary offer) async {
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
      await ref.read(salesOfferRepositoryProvider).cancelOffer(offer.id);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُوقف العرض');
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openComments(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return CommentsSheet.show(
      context,
      loadComments: () => repo.getWarehouseComments(offer.id),
      addComment: (text) => repo.addWarehouseComment(offer.id, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروضي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إنشاء عرض جديد',
        onPressed: () async {
          await context.push(TRoutes.whCreateOffer);
          if (mounted) await _load(silent: true);
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _offers ?? const <SalesOfferSummary>[];
    final shown = all.where((o) => _tab.matches(o.status)).toList();
    final expiring = _expiringSoon.length;
    final tk = context.tokens;

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            itemCount: _OffersTab.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final t = _OffersTab.values[i];
              return AppFilterChip(
                label: t.label,
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              );
            },
          ),
        ),

        // سطر الحالة: السارية، ثم تحذير ما يقارب على الانتهاء.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              [
                '${_active.length} ${_active.length == 1 ? 'عرض سارٍ' : 'عرضاً سارياً'}',
                if (expiring > 0)
                  '$expiring ${expiring == 1 ? 'ينتهي قريباً' : 'تنتهي قريباً'}',
              ].join(' · '),
              style: context.text.bodySmall
                  ?.copyWith(color: expiring > 0 ? tk.warning : tk.hint),
            ),
          ),
        ),

        Expanded(
          child: shown.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.sell_outlined,
                      message: _tab == _OffersTab.all
                          ? 'لا عروض بعد — أنشئ عرضاً ليصل الصيدليات التي تخدمها'
                          : 'لا عروض في «${_tab.label}»',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, 88),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => _card(shown[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(SalesOfferSummary o) {
    final days = o.expiresAt.difference(DateTime.now()).inDays;
    final expiringSoon =
        o.status == SalesOfferStatus.active && days >= 0 && days <= 3;

    // «ينتهي قريباً» تسبق «منشور» في الشارة: الأهمّ ما يستدعي إجراءً،
    // لا ما هو قائم أصلاً.
    final (label, tone) = switch (o.status) {
      SalesOfferStatus.active when expiringSoon =>
        ('ينتهي قريباً', StatusTone.warning),
      SalesOfferStatus.active => ('منشور', StatusTone.success),
      SalesOfferStatus.draft => ('مسودة', StatusTone.neutral),
      SalesOfferStatus.cancelled => ('متوقف', StatusTone.danger),
      SalesOfferStatus.expired => ('منتهٍ', StatusTone.neutral),
    };

    final bonus = switch ((o.hasItemBonus, o.hasOfferBonus)) {
      (true, true) => 'بونص أصناف + بونص على كامل العرض',
      (true, false) => 'بونص أصناف فقط',
      (false, true) => 'بونص على كامل العرض',
      _ => 'بلا بونص',
    };

    return WarehouseOfferCard(
      title: o.title,
      itemsText: '${o.itemCount} ${o.itemCount == 1 ? 'صنف' : 'أصناف'} · $bonus',
      expiryText: switch (o.status) {
        SalesOfferStatus.draft => 'لم تُنشر بعد',
        SalesOfferStatus.cancelled =>
          'أُوقف ${formatSmartTimestamp(o.expiresAt)}',
        _ when o.expiresAt.isBefore(DateTime.now()) =>
          'انتهى ${formatSmartTimestamp(o.expiresAt)}',
        _ => 'ينتهي ${formatSmartTimestamp(o.expiresAt)}',
      },
      statusLabel: label,
      statusTone: tone,
      lastUpdateText: 'أُنشئ ${formatSmartTimestamp(o.createdOn)}',
      // المسودة تُنشر، والمنشور تُقرأ تعليقاته — الزرّ يسمّي ما سيحدث فعلاً.
      // (الخادم لا يتيح تعديل عرض منشور، فلا نَعِد بزرّ «تعديل».)
      editLabel: o.status == SalesOfferStatus.draft ? 'نشر' : 'التعليقات',
      onEdit: _busy
          ? null
          : o.status == SalesOfferStatus.draft
              ? () => _publish(o)
              : () => _openComments(o),
      // الإيقاف للمسودة والمنشور فقط — ما انتهى أو أُوقف لا يُوقف.
      onStop: _busy ||
              o.status == SalesOfferStatus.expired ||
              o.status == SalesOfferStatus.cancelled
          ? null
          : () => _stop(o),
      onTap: () => context.push(TRoutes.whOfferDetail(o.id)),
    );
  }
}
