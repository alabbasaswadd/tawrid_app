import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/comments_sheet.dart';
import 'package:tawrid_app/shared/widgets/governorate_city_selector.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_detail_sheet.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_post_card.dart';

// الصفحة الرئيسية للمستودع — مفتاح تبديل بين "عروضي" و"مناقصات مفتوحة".
class WhHomePage extends ConsumerStatefulWidget {
  const WhHomePage({super.key});

  @override
  ConsumerState<WhHomePage> createState() => _WhHomePageState();
}

class _WhHomePageState extends ConsumerState<WhHomePage> {
  List<SalesOfferSummary>? _offers;
  bool _offersLoading = true;
  String? _offersError;
  String? _offersGovernorateFilter;

  List<TenderSummary>? _tenders;
  bool _tendersLoading = true;
  String? _tendersError;
  String? _tendersGovernorateId;
  String? _tendersCityId;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _loadTenders();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _offersLoading = true;
      _offersError = null;
    });
    try {
      final list = await ref.read(salesOfferRepositoryProvider).getMyOffers();
      setState(() {
        _offers = list;
        _offersLoading = false;
      });
    } catch (e) {
      setState(() {
        _offersError = ApiException.from(e).message;
        _offersLoading = false;
      });
    }
  }

  Future<void> _loadTenders() async {
    setState(() {
      _tendersLoading = true;
      _tendersError = null;
    });
    try {
      final list = await ref.read(tenderRepositoryProvider).getOpenTenders();
      setState(() {
        _tenders = list;
        _tendersLoading = false;
      });
    } catch (e) {
      setState(() {
        _tendersError = ApiException.from(e).message;
        _tendersLoading = false;
      });
    }
  }

  List<SalesOfferSummary> get _filteredOffers {
    final list = _offers ?? [];
    final filter = _offersGovernorateFilter;
    if (filter == null) return list;
    return list.where((o) => o.targetRegions.any((r) => r.governorate == filter)).toList();
  }

  List<TenderSummary> _filteredTenders(String? govName, String? cityName) {
    final list = _tenders ?? [];
    return list.where((t) {
      if (govName != null && t.tenantGovernorate != govName) return false;
      if (cityName != null && t.tenantCity != cityName) return false;
      return true;
    }).toList();
  }

  Future<void> _openOfferDetails(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return SalesOfferDetailSheet.show(context, load: () => repo.getWarehouseOfferById(offer.id));
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
    final governorates = ref.watch(governoratesProvider).value ?? [];
    final busy = _offersLoading || _tendersLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: busy ? null : () => Future.wait([_loadOffers(), _loadTenders()]),
          ),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: AppSegmentedToggle(
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
              items: [
                SegmentItem(
                  icon: Icons.sell_outlined,
                  label: _offers == null ? 'عروضي' : 'عروضي (${_offers!.length})',
                ),
                SegmentItem(
                  icon: Icons.gavel_outlined,
                  label: _tenders == null ? 'مناقصات مفتوحة' : 'مناقصات مفتوحة (${_tenders!.length})',
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _OffersTab(
                  governorates: governorates,
                  offers: _filteredOffers,
                  loading: _offersLoading,
                  error: _offersError,
                  filter: _offersGovernorateFilter,
                  onFilterChanged: (v) => setState(() => _offersGovernorateFilter = v),
                  onRefresh: _loadOffers,
                  onDetails: _openOfferDetails,
                  onComments: _openComments,
                ),
                _TendersTab(
                  governorates: governorates,
                  loading: _tendersLoading,
                  error: _tendersError,
                  governorateId: _tendersGovernorateId,
                  cityId: _tendersCityId,
                  onGovernorateChanged: (v) => setState(() {
                    _tendersGovernorateId = v;
                    _tendersCityId = null;
                  }),
                  onCityChanged: (v) => setState(() => _tendersCityId = v),
                  filtered: (govName, cityName) => _filteredTenders(govName, cityName),
                  onRefresh: _loadTenders,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── تبويب "عروضي" ───────────────────────────────────────────────────────
class _OffersTab extends StatelessWidget {
  const _OffersTab({
    required this.governorates,
    required this.offers,
    required this.loading,
    required this.error,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onDetails,
    required this.onComments,
  });

  final List governorates;
  final List<SalesOfferSummary> offers;
  final bool loading;
  final String? error;
  final String? filter;
  final ValueChanged<String?> onFilterChanged;
  final Future<void> Function() onRefresh;
  final void Function(SalesOfferSummary) onDetails;
  final void Function(SalesOfferSummary) onComments;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    _GovernorateOnlyFilter(governorates: governorates, value: filter, onChanged: onFilterChanged),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: RefreshIndicator(onRefresh: onRefresh, child: _buildBody())),
      ],
    );
  }

  Widget _buildBody() {
    if (loading) return const LoadingState();
    if (error != null) return ErrorState(message: error!, onRetry: onRefresh);
    if (offers.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(message: 'لا توجد عروض مطابقة', icon: Icons.sell_outlined),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return SalesOfferPostCard(
          offer: offer,
          onDetails: () => onDetails(offer),
          onComments: () => onComments(offer),
        );
      },
    );
  }
}

// ── تبويب "مناقصات مفتوحة" ──────────────────────────────────────────────
class _TendersTab extends StatelessWidget {
  const _TendersTab({
    required this.governorates,
    required this.loading,
    required this.error,
    required this.governorateId,
    required this.cityId,
    required this.onGovernorateChanged,
    required this.onCityChanged,
    required this.filtered,
    required this.onRefresh,
  });

  final List governorates;
  final bool loading;
  final String? error;
  final String? governorateId;
  final String? cityId;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String?> onCityChanged;
  final List<TenderSummary> Function(String? govName, String? cityName) filtered;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    String? govName;
    String? cityName;
    final govId = governorateId;
    if (govId != null) {
      for (final g in governorates) {
        if (g.id == govId) {
          govName = g.name;
          final cid = cityId;
          if (cid != null) {
            for (final c in g.cities) {
              if (c.id == cid) cityName = c.name;
            }
          }
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: context.tokens.surfaceAlt,
            child: GovernorateCitySelector(
              governorateId: governorateId,
              cityId: cityId,
              onGovernorateChanged: onGovernorateChanged,
              onCityChanged: onCityChanged,
            ),
          ),
        ),
        Expanded(child: RefreshIndicator(onRefresh: onRefresh, child: _buildBody(filtered(govName, cityName)))),
      ],
    );
  }

  Widget _buildBody(List<TenderSummary> tenders) {
    if (loading) return const LoadingState();
    if (error != null) return ErrorState(message: error!, onRetry: onRefresh);
    if (tenders.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(message: 'لا توجد مناقصات مطابقة', icon: Icons.gavel_outlined),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: tenders.length,
      itemBuilder: (context, index) {
        final tender = tenders[index];
        return _TenderPostCard(
          tender: tender,
          onApply: () => context.push(TRoutes.whSubmitTenderOffer(tender.id)),
        );
      },
    );
  }
}

// فلتر محافظة واحد (بلا مدينة) لـ "عروضي".
class _GovernorateOnlyFilter extends StatelessWidget {
  const _GovernorateOnlyFilter({required this.governorates, required this.value, required this.onChanged});

  final List governorates;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      underline: const SizedBox.shrink(),
      hint: Text('المنطقة', style: context.text.bodySmall),
      style: context.text.bodySmall,
      items: [
        DropdownMenuItem(value: null, child: Text('الكل', style: context.text.bodySmall)),
        ...governorates.map((g) => DropdownMenuItem(
              value: g.name as String,
              child: Text(g.name as String, style: context.text.bodySmall),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

// بطاقة مناقصة — أسلوب موحّد مع شريط حالة جانبي.
class _TenderPostCard extends StatelessWidget {
  const _TenderPostCard({required this.tender, required this.onApply});
  final TenderSummary tender;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    final region = [tender.tenantGovernorate, tender.tenantCity].where((e) => e != null && e.isNotEmpty).join(' - ');
    final statusColor = tender.isExpired ? cs.error : t.success;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: statusColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tender.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: '${tender.isExpired ? "منتهية" : "مفتوحة"} · ${tender.itemCount} صنف · ${formatSmartTimestamp(tender.createdOn)}',
                    tone: tender.isExpired ? StatusTone.danger : StatusTone.success,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(region.isEmpty ? 'بلا منطقة' : region,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      ),
                      Text('ينتهي ${formatSmartTimestamp(tender.expiresAt)}', style: context.text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'تقدّم بعرض',
                    icon: Icons.send_outlined,
                    onPressed: tender.isExpired ? null : onApply,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
