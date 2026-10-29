import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';

class PhCartItem {
  const PhCartItem({
    required this.offerId,
    required this.offerTitle,
    required this.warehouseName,
    required this.itemCount,
    required this.offer,
  });

  final String offerId;
  final String offerTitle;
  final String warehouseName;
  final int itemCount;
  final SalesOfferSummary offer;
}

class PhCartNotifier extends Notifier<List<PhCartItem>> {
  @override
  List<PhCartItem> build() => const [];

  bool contains(String offerId) => state.any((i) => i.offerId == offerId);

  void add(SalesOfferSummary offer) {
    if (contains(offer.id)) return;
    state = [
      ...state,
      PhCartItem(
        offerId: offer.id,
        offerTitle: offer.title,
        warehouseName: offer.warehouseName,
        itemCount: offer.itemCount,
        offer: offer,
      ),
    ];
  }

  void remove(String offerId) {
    state = state.where((i) => i.offerId != offerId).toList();
  }

  void clear() => state = const [];
}

final phCartProvider =
    NotifierProvider<PhCartNotifier, List<PhCartItem>>(
  PhCartNotifier.new,
);
