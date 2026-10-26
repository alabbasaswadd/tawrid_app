import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

/// نغمة شارة حالة طلب التسعير — تُستعمل أيضاً في شاشة المقارنة.
StatusTone tenderTone(TenderStatus s) => switch (s) {
      TenderStatus.open => StatusTone.success,
      TenderStatus.closed => StatusTone.warning,
      TenderStatus.awarded => StatusTone.brand,
      TenderStatus.cancelled => StatusTone.danger,
      TenderStatus.draft => StatusTone.neutral,
    };

// تبويبات الطلبات (Figma): المفتوحة / المغلقة / المسودات.
//
// «المغلقة» تضم كل ما انتهت مهلته أو حُسم: منتهٍ بانتظار الترسية، ومُرسًى،
// وملغًى. الصيدلي لا يفرّق بينها وهو يتصفّح — يفرّق بين «ما زال يستقبل
// عروضاً» و«انتهى» و«لم يُنشر بعد».
enum _RequestsTab {
  open('المفتوحة'),
  closed('المغلقة'),
  drafts('المسودات');

  const _RequestsTab(this.label);
  final String label;

  bool matches(TenderSummary t) => switch (this) {
        _RequestsTab.open => t.status == TenderStatus.open && !t.isExpired,
        _RequestsTab.drafts => t.status == TenderStatus.draft,
        _RequestsTab.closed => t.status != TenderStatus.draft &&
            (t.isExpired || t.status != TenderStatus.open),
      };

  String countLabel(int n) => switch (this) {
        _RequestsTab.open =>
          '$n ${n == 1 ? 'طلب تسعير مفتوح' : 'طلبات تسعير مفتوحة'}',
        _RequestsTab.closed =>
          '$n ${n == 1 ? 'طلب تسعير مغلق' : 'طلبات تسعير مغلقة'}',
        _RequestsTab.drafts => '$n ${n == 1 ? 'مسودة' : 'مسودات'}',
      };

  String get emptyMessage => switch (this) {
        _RequestsTab.open =>
          'لا طلبات تسعير مفتوحة — انشر طلباً بأصنافك وكمياتك لتصلك عروض '
              'أسعار من المستودعات التي تخدم مدينتك',
        _RequestsTab.closed => 'لا طلبات مغلقة بعد',
        _RequestsTab.drafts =>
          'لا مسودات — المسودة طلبٌ محفوظ لم يُنشر، لا يراه أي مستودع',
      };
}

// طلبات التسعير عند الصيدلي (Figma: الصيدلي / طلبات التسعير).
class PhTendersPage extends ConsumerStatefulWidget {
  const PhTendersPage({super.key});

  @override
  ConsumerState<PhTendersPage> createState() => _PhTendersPageState();
}

class _PhTendersPageState extends ConsumerState<PhTendersPage> {
  List<TenderSummary>? _requests;
  bool _loading = true;
  String? _error;
  _RequestsTab _tab = _RequestsTab.open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] يُحدّث بلا مؤشّر تحميل، فتبقى القائمة وموضع التمرير كما هما.
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(tenderRepositoryProvider).getMyTenders(limit: 50);
      if (!mounted) return;
      setState(() {
        _requests = list;
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

  Future<void> _create() async {
    final created = await context.push<bool>(TRoutes.phCreateTender);
    if (created == true && mounted) {
      setState(() => _tab = _RequestsTab.open);
      await _load(silent: true);
    }
  }

  Future<void> _open(TenderSummary t) async {
    await context.push(TRoutes.phCompareQuotations(t.id));
    // بصمت: الرجوع من المقارنة ليس سبباً لإعادة بناء الشاشة أمام المستخدم.
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التسعير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'طلب تسعير جديد',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final all = _requests ?? const <TenderSummary>[];
    final shown = all.where(_tab.matches).toList();
    final tk = context.tokens;
    final area = ref.watch(pharmacyMeProvider).value?.areaLabel;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
          child: Row(
            children: [
              for (final t in _RequestsTab.values)
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
              AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.sm),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(_tab.countLabel(shown.length),
                style: context.text.bodySmall?.copyWith(color: tk.hint)),
          ),
        ),

        Expanded(
          child: shown.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: AppSpacing.x3l),
                    EmptyState(
                      icon: Icons.request_quote_outlined,
                      message: _tab.emptyMessage,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, 88),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, i) => _card(shown[i], area),
                ),
        ),
      ],
    );
  }

  // بطاقة طلب التسعير من مكتبة التصميم (Figma: بطاقة طلب تسعير).
  Widget _card(TenderSummary t, String? area) {
    final awaiting = t.isExpired &&
        (t.status == TenderStatus.open || t.status == TenderStatus.closed);

    return TenderCard(
      title: t.title,
      itemsText: '${t.itemCount} ${t.itemCount == 1 ? 'صنف مطلوب' : 'أصناف مطلوبة'}'
          ' · كميات محددة',
      deadlineText: switch (t.status) {
        TenderStatus.draft => 'مسودة — لم تُنشر بعد',
        _ when t.isExpired => 'أُغلقت ${formatSmartTimestamp(t.expiresAt)}',
        _ => 'استقبال العروض حتى ${formatSmartTimestamp(t.expiresAt)}',
      },
      deliveryText: 'التسليم: ${area ?? '—'}',
      statusLabel: awaiting ? 'بانتظار الترسية' : t.status.label,
      statusTone: awaiting ? StatusTone.warning : tenderTone(t.status),
      // العدد مرئي دائماً؛ أما تفاصيل العروض فيحجبها الخادم حتى المهلة.
      offersCountLabel: t.status == TenderStatus.draft
          ? null
          : t.status == TenderStatus.awarded
              ? '${t.offerCount} عروض — تمت الترسية'
              : '${t.offerCount} ${t.offerCount == 1 ? 'عرض مستلم' : 'عروض مستلمة'}',
      compareLabel: t.status == TenderStatus.draft
          ? 'إكمال المسودة'
          : 'عرض العروض والمقارنة',
      onCompare: () => _open(t),
      onTap: () => _open(t),
    );
  }
}
