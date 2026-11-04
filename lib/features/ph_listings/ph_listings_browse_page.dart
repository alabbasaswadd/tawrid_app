import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'widgets/ph_listing_card.dart';

// شاشة تصفح إعلانات «صيدلي إلى صيدلي» — تظهر للصيادلة فقط.
// يمكن تصفيتها بالمحافظة أو بسبب البيع، والبحث بالاسم.
class PhListingsBrowsePage extends ConsumerStatefulWidget {
  const PhListingsBrowsePage({super.key});

  @override
  ConsumerState<PhListingsBrowsePage> createState() =>
      _PhListingsBrowsePageState();
}

class _PhListingsBrowsePageState extends ConsumerState<PhListingsBrowsePage> {
  List<PhListingSummary>? _items;
  bool _loading = true;
  String? _error;
  String _search = '';
  PhListingReason? _filterReason;

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
      final list = await ref.read(phListingRepositoryProvider).getListings(
            reason: _filterReason,
            search: _search.trim().isEmpty ? null : _search.trim(),
          );
      if (!mounted) return;
      setState(() {
        _items = list;
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
      appBar: const InnerTopBar(title: 'صيدلي إلى صيدلي'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.card);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final tk = context.tokens;
    final items = _items ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.x3l,
      ),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'أدوية صيادلة بمنطقتك — تواصل معهم مباشرة عبر المحادثة.',
          style: context.text.bodySmall?.copyWith(color: tk.hint),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── بحث ────────────────────────────────────────────────────────────
        AppSearchBar(
          hint: 'ابحث باسم الدواء',
          onChanged: (v) {
            _search = v;
            _load();
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── فلتر السبب ──────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ReasonChip(
                label: 'الكل',
                selected: _filterReason == null,
                onTap: () {
                  setState(() => _filterReason = null);
                  _load();
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              for (final r in PhListingReason.values) ...[
                _ReasonChip(
                  label: r.label,
                  selected: _filterReason == r,
                  onTap: () {
                    setState(
                        () => _filterReason = _filterReason == r ? null : r);
                    _load();
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── قائمة الإعلانات ─────────────────────────────────────────────────
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3l),
            child: UiEmpty(
              appIcon: AppIcons.pill,
              message: _filterReason != null || _search.isNotEmpty
                  ? 'لا إعلانات تطابق بحثك'
                  : 'لا إعلانات متاحة حالياً في منطقتك',
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PhListingCard(
                listing: item,
                onTap: () => context.push(TRoutes.phListingDetail(item.id)),
              ),
            ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppFilterChip(label: label, selected: selected, onTap: onTap);
  }
}
