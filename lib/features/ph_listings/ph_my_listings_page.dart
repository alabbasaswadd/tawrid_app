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

// إعلاناتي — الصيدلي 1 يرى إعلاناته ويديرها (قبول/رفض الحجوزات وإضافة جديد).
class PhMyListingsPage extends ConsumerStatefulWidget {
  const PhMyListingsPage({super.key});

  @override
  ConsumerState<PhMyListingsPage> createState() => _PhMyListingsPageState();
}

class _PhMyListingsPageState extends ConsumerState<PhMyListingsPage> {
  List<PhListingSummary>? _items;
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
      final list =
          await ref.read(phListingRepositoryProvider).getMyListings();
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
    final active = (_items ?? [])
        .where((l) => l.status == PhListingStatus.available ||
            l.status == PhListingStatus.booked)
        .toList();
    final closed = (_items ?? [])
        .where((l) => l.status == PhListingStatus.closed)
        .toList();

    return Scaffold(
      appBar: const InnerTopBar(title: 'إعلاناتي'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(TRoutes.phListingCreate).then((_) => _load()),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(active, closed)),
    );
  }

  Widget _buildBody(
    List<PhListingSummary> active,
    List<PhListingSummary> closed,
  ) {
    if (_loading) return const AppListSkeleton(variant: SkeletonVariant.card);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if ((_items ?? []).isEmpty) {
      return UiEmpty(
        appIcon: AppIcons.package,
        message: 'لا إعلانات بعد — اضغط «إعلان جديد» لإضافة أول إعلان',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, 100,
      ),
      children: [
        if (active.isNotEmpty) ...[
          AppSectionHeader(title: 'النشطة (${active.length})'),
          const SizedBox(height: AppSpacing.sm),
          for (final item in active)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PhListingCard(
                listing: item,
                isOwner: true,
                onTap: () =>
                    context.push(TRoutes.phListingDetail(item.id)).then(
                          (_) => _load(),
                        ),
              ),
            ),
        ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppSectionHeader(title: 'المغلقة (${closed.length})'),
          const SizedBox(height: AppSpacing.sm),
          for (final item in closed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PhListingCard(
                listing: item,
                isOwner: true,
                onTap: () =>
                    context.push(TRoutes.phListingDetail(item.id)),
              ),
            ),
        ],
      ],
    );
  }
}
