import 'dart:async';

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
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

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

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // بدون ديباونس: كل حرف يطلب إعادة تحميل كاملة تُظهر هيكل تحميل يُخفي
  // حقل البحث نفسه — فيفقد تركيزه ولوحة المفاتيح أثناء الكتابة. نصف ثانية
  // قبل الطلب تمنع ذلك وتمنع رحلة شبكة لكل حرف.
  void _onSearchChanged(String v) {
    _search = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
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

  // الشريط والفلاتر ثابتان دائماً — لا يختفيان أثناء إعادة التحميل، حتى لا
  // يفقد حقل البحث تركيزه ولوحة المفاتيح مع كل حرف يُكتب.
  Widget _buildBody() {
    final tk = context.tokens;

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
          controller: _searchCtrl,
          hint: 'ابحث باسم الدواء',
          onChanged: _onSearchChanged,
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

        // ── نتائج البحث ──────────────────────────────────────────────────
        _buildResults(),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppListSkeleton(variant: SkeletonVariant.card, count: 3),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final items = _items ?? const [];
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3l),
        child: UiEmpty(
          appIcon: AppIcons.pill,
          message: _filterReason != null || _search.isNotEmpty
              ? 'لا إعلانات تطابق بحثك'
              : 'لا إعلانات متاحة حالياً في منطقتك',
        ),
      );
    }

    return Column(
      children: [
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
