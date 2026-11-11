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
import 'package:tawrid_app/shared/widgets/app_states.dart';

class PhTenderReportsPage extends ConsumerStatefulWidget {
  const PhTenderReportsPage({super.key});

  @override
  ConsumerState<PhTenderReportsPage> createState() =>
      _PhTenderReportsPageState();
}

class _PhTenderReportsPageState extends ConsumerState<PhTenderReportsPage> {
  List<TenderSummary> _tenders = const [];
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
      final tenders = await ref
          .read(tenderRepositoryProvider)
          .getMyTenders(limit: 500);
      if (!mounted) return;
      setState(() {
        _tenders = tenders;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'تقرير طلبات التسعير'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const AppDetailSkeleton()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_tenders.isEmpty) {
      return const UiEmpty(
        message: 'لا طلبات تسعير حتى الآن',
        description: 'ستظهر هنا إحصائيات طلبات التسعير بعد إنشاء أول طلب.',
      );
    }

    final byStatus = <TenderStatus, int>{};
    for (final t in _tenders) {
      byStatus[t.status] = (byStatus[t.status] ?? 0) + 1;
    }

    final awarded = byStatus[TenderStatus.awarded] ?? 0;
    final open = byStatus[TenderStatus.open] ?? 0;
    final recent = _tenders.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        // ── ملخّص رقمي ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SummaryCounter(
                value: '${_tenders.length}',
                label: 'إجمالي الطلبات',
                icon: AppIcons.fileText,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SummaryCounter(
                value: '$awarded',
                label: 'تم ترسيتها',
                icon: AppIcons.check,
              ),
            ),
          ],
        ),

        if (open > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoBanner(
            label: 'يوجد $open طلب مفتوح بانتظار عروض الأسعار',
            onTap: () => context.push(TRoutes.phTenders),
          ),
        ],

        const SizedBox(height: AppSpacing.x2l),
        AppSectionHeader(title: 'توزيع الطلبات حسب الحالة'),
        const SizedBox(height: AppSpacing.md),

        // ── توزيع الحالات ────────────────────────────────────────────────
        for (final entry in byStatus.entries)
          if (entry.value > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StatusRow(status: entry.key, count: entry.value),
            ),

        const SizedBox(height: AppSpacing.x2l),
        AppSectionHeader(
          title: 'أحدث الطلبات',
          trailing: _SeeAllLink(onTap: () => context.push(TRoutes.phTenders)),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── أحدث 5 طلبات ──────────────────────────────────────────────
        for (final t in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TenderRow(
              tender: t,
              onTap: () => context.push(TRoutes.phCompareQuotations(t.id)),
            ),
          ),
      ],
    );
  }
}

// ── شارة تنبيه طلبات مفتوحة ───────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: tk.brandSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.bell, size: 16, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyMedium?.copyWith(color: cs.primary),
              ),
            ),
            AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// ── صف حالة ───────────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, required this.count});
  final TenderStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
        boxShadow: tk.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(status.label, style: context.text.bodyMedium),
          ),
          Text(
            '$count',
            style: context.text.titleMedium?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('طلب', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

// ── صف طلب تسعير ──────────────────────────────────────────────────────────
class _TenderRow extends StatelessWidget {
  const _TenderRow({required this.tender, required this.onTap});
  final TenderSummary tender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline),
          boxShadow: tk.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tender.title,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tender.tenderNumber} · '
                    '${tender.itemCount} صنف · '
                    '${tender.offerCount} عرض',
                    style: context.text.bodySmall
                        ?.copyWith(color: tk.hint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              label: tender.status.label,
              tone: _tone(tender.status),
            ),
          ],
        ),
      ),
    );
  }

  static StatusTone _tone(TenderStatus s) => switch (s) {
        TenderStatus.open => StatusTone.info,
        TenderStatus.awarded => StatusTone.success,
        TenderStatus.cancelled => StatusTone.danger,
        TenderStatus.draft => StatusTone.neutral,
        TenderStatus.closed => StatusTone.warning,
      };
}

// ── رابط «عرض الكل» ───────────────────────────────────────────────────────
class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'عرض الكل',
            style: context.text.bodySmall?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: 2),
          AppIcon(AppIcons.chevronForwardRtl, size: 14, color: cs.primary),
        ],
      ),
    );
  }
}
