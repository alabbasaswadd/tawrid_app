import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/comments_sheet.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_detail_sheet.dart';
import 'package:tawrid_app/shared/widgets/sales_offer_post_card.dart';

// صفحة "عروضي" — قائمة كل عروض البيع الخاصة بالمستودع (بلا فلترة)، مع
// زر تحديث صريح بالأعلى وسحب للتحديث، بدل الحالة الفارغة الثابتة سابقاً.
class WhOffersPage extends ConsumerStatefulWidget {
  const WhOffersPage({super.key});

  @override
  ConsumerState<WhOffersPage> createState() => _WhOffersPageState();
}

class _WhOffersPageState extends ConsumerState<WhOffersPage> {
  List<SalesOfferSummary>? _offers;
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
      final list = await ref.read(salesOfferRepositoryProvider).getMyOffers();
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

  Future<void> _openDetails(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return SalesOfferDetailSheet.show(
      context,
      load: () => repo.getWarehouseOfferById(offer.id),
    );
  }

  Future<void> _openComments(SalesOfferSummary offer) {
    final repo = ref.read(salesOfferRepositoryProvider);
    return CommentsSheet.show(
      context,
      loadComments: () => repo.getWarehouseComments(offer.id),
      addComment: (text) => repo.addWarehouseComment(offer.id, text),
    );
  }

  Future<void> _publish(SalesOfferSummary offer) async {
    try {
      await ref.read(salesOfferRepositoryProvider).publishOffer(offer.id);
      if (mounted) {
        AppSnackbar.success(context, 'تم نشر العرض');
        _load();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  Future<void> _cancel(SalesOfferSummary offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء العرض'),
        content: Text('هل تريد إلغاء "${offer.title}"؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء العرض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(salesOfferRepositoryProvider).cancelOffer(offer.id);
      if (mounted) {
        AppSnackbar.success(context, 'تم إلغاء العرض');
        _load();
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(TRoutes.whCreateOffer);
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('عرض جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final offers = _offers ?? [];
    if (offers.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            message: 'لا توجد عروض — أنشئ عرض بيع جديداً لتعرضه على الصيدليات',
            icon: Icons.sell_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return SalesOfferPostCard(
          offer: offer,
          onDetails: () => _openDetails(offer),
          onComments: () => _openComments(offer),
          onPublish: () => _publish(offer),
          onCancel: () => _cancel(offer),
        );
      },
    );
  }
}
