import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/tender_models.dart';

final tenderRepositoryProvider = Provider<TenderRepository>((ref) {
  return TenderRepository(ref.watch(apiClientProvider));
});

class TenderRepository {
  TenderRepository(this._api);
  final ApiClient _api;

  // ── جهة الصيدلي ──────────────────────────────────────────────────────
  Future<List<TenderSummary>> getMyTenders({int limit = 20, int offset = 0}) async {
    final data = await _api.get(ApiEndpoints.phTenders,
        queryParameters: {'limit': limit, 'offset': offset}) as List;
    return data.map((e) => TenderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TenderDetail> createTender({
    required String title,
    String? description,
    required DateTime expiresAt,
    required List<TenderItem> items,
  }) async {
    final data = await _api.post(ApiEndpoints.phTenders, data: {
      'title': title,
      'description': description,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'items': items.map((e) => e.toCreateJson()).toList(),
    }) as Map<String, dynamic>;
    return TenderDetail.fromJson(data);
  }

  Future<TenderDetail> getTenderById(String id) async {
    final data = await _api.get(ApiEndpoints.phTenderById(id)) as Map<String, dynamic>;
    return TenderDetail.fromJson(data);
  }

  Future<void> cancelTender(String id) => _api.post(ApiEndpoints.phTenderCancel(id));

  Future<SelectOfferResult> selectOffer(String tenderId, String offerId, {String? winnerNotes}) async {
    final data = await _api.post(
      ApiEndpoints.phTenderSelectOffer(tenderId, offerId),
      data: {'winnerNotes': winnerNotes},
    ) as Map<String, dynamic>;
    return SelectOfferResult.fromJson(data);
  }

  // ── جهة المستودع ─────────────────────────────────────────────────────
  Future<List<TenderSummary>> getOpenTenders({int limit = 20, int offset = 0}) async {
    final data = await _api.get(ApiEndpoints.whTendersOpen,
        queryParameters: {'limit': limit, 'offset': offset}) as List;
    return data.map((e) => TenderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  // تفاصيل مناقصة (أصنافها) قبل التقدّم بعرض — بلا أي معلومة عن المنافسين.
  Future<TenderDetail> getTenderDetailsForWarehouse(String tenderId) async {
    final data = await _api.get(ApiEndpoints.whTenderById(tenderId)) as Map<String, dynamic>;
    return TenderDetail.fromJson(data);
  }

  Future<List<MyTenderOfferSummary>> getMyOffers({int limit = 20, int offset = 0}) async {
    final data = await _api.get(ApiEndpoints.whMyOffers,
        queryParameters: {'limit': limit, 'offset': offset}) as List;
    return data.map((e) => MyTenderOfferSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TenderOffer> submitOffer({
    required String tenderId,
    required int offerType, // TenderOfferType.code
    String? notes,
    required List<Map<String, dynamic>> items, // {tenderItemId, unitPrice?, bonusPercentage?, extraBonus?, notes?}
  }) async {
    final data = await _api.post(ApiEndpoints.whTenderSubmit(tenderId), data: {
      'offerType': offerType,
      'notes': notes,
      'items': items,
    }) as Map<String, dynamic>;
    return TenderOffer.fromJson(data);
  }
}
