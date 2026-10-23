import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/comments_sheet.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_detail_sheet.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_post_card.dart';

// عروض المستودعات المتاحة للصيدلية (تشمل منطقتها) — بحث + سحب للتحديث.
class PhOffersPage extends ConsumerStatefulWidget {
  const PhOffersPage({super.key});

  @override
  ConsumerState<PhOffersPage> createState() => _PhOffersPageState();
}

class _PhOffersPageState extends ConsumerState<PhOffersPage> {
  List<SalesOfferSummary>? _offers;
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final list = await ref.read(salesOfferRepositoryProvider).getAvailableOffers(limit: 100);
      setState(() {
        _offers = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  List<SalesOfferSummary> get _filtered {
    final list = _offers ?? [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((o) =>
        o.title.toLowerCase().contains(q) ||
        o.warehouseName.toLowerCase().contains(q) ||
        o.itemNames.any((n) => n.toLowerCase().contains(q))).toList();
  }

  Future<void> _openDetails(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return SalesOfferDetailSheet.show(context, load: () => repo.getOfferById(offer.id));
  }

  Future<void> _openComments(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return CommentsSheet.show(
      context,
      loadComments: () => repo.getPharmacyComments(offer.id),
      addComment: (text) => repo.addPharmacyComment(offer.id, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض المستودعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'ابحث عن عرض أو دواء أو مستودع...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final offers = _filtered;
    if (offers.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(message: 'لا توجد عروض متاحة في منطقتك حالياً', icon: Icons.sell_outlined),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return SalesOfferPostCard(
          offer: offer,
          onDetails: () => _openDetails(offer),
          onComments: () => _openComments(offer),
        );
      },
    );
  }
}
