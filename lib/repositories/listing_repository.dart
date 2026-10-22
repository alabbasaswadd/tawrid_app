import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/listing_models.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository(ref.watch(apiClientProvider));
});

class ListingRepository {
  ListingRepository(this._api);
  final ApiClient _api;

  // ── جهة الصيدلي ──────────────────────────────────────────────────────
  Future<ListingDetail> createListing({
    required String medicineName,
    String? catalogItemId,
    required double quantity,
    required String unit,
    required double askingPrice,
    String? description,
    required ListingBuyerType buyerType,
    required DateTime expiresAt,
  }) async {
    final data = await _api.post(ApiEndpoints.phPublicListings, data: {
      'medicineName': medicineName,
      'catalogItemId': catalogItemId,
      'quantity': quantity,
      'unit': unit,
      'askingPrice': askingPrice,
      'description': description,
      'buyerType': buyerType.code,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return ListingDetail.fromJson(data);
  }

  Future<List<ListingSummary>> getMyListings({
    PharmacyListingStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get(ApiEndpoints.phMyListings, queryParameters: {
      if (status != null) 'status': status.code,
      'limit': limit,
      'offset': offset,
    }) as List;
    return data.map((e) => ListingSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ListingSummary>> getPublicListings({int limit = 20, int offset = 0}) async {
    final data = await _api.get(ApiEndpoints.phPublicListings,
        queryParameters: {'limit': limit, 'offset': offset}) as List;
    return data.map((e) => ListingSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ListingDetail> getListingById(String id) async {
    final data = await _api.get(ApiEndpoints.phListingById(id)) as Map<String, dynamic>;
    return ListingDetail.fromJson(data);
  }

  Future<void> markSold(String id) => _api.post(ApiEndpoints.phListingSold(id));

  Future<void> cancelListing(String id) => _api.post(ApiEndpoints.phListingCancel(id));

  Future<OfferComment> addPharmacyComment(String id, String content) async {
    final data = await _api.post(ApiEndpoints.phListingComments(id), data: {'content': content})
        as Map<String, dynamic>;
    return OfferComment.fromJson(data);
  }

  Future<List<OfferComment>> getPharmacyComments(String id) async {
    final data = await _api.get(ApiEndpoints.phListingComments(id)) as List;
    return data.map((e) => OfferComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deletePharmacyComment(String id, String commentId) =>
      _api.delete(ApiEndpoints.phListingCommentById(id, commentId));

  // ── جهة المستودع (تصفّح إعلانات الصيدليات) ───────────────────────────
  Future<List<ListingSummary>> getPublicListingsForWarehouse({
    String? governorate,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get(ApiEndpoints.whListings, queryParameters: {
      'governorate': ?governorate,
      'limit': limit,
      'offset': offset,
    }) as List;
    return data.map((e) => ListingSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ListingDetail> getListingByIdForWarehouse(String id) async {
    final data = await _api.get(ApiEndpoints.whListingById(id)) as Map<String, dynamic>;
    return ListingDetail.fromJson(data);
  }

  Future<OfferComment> addWarehouseComment(String id, String content) async {
    final data = await _api.post(ApiEndpoints.whListingComments(id), data: {'content': content})
        as Map<String, dynamic>;
    return OfferComment.fromJson(data);
  }

  Future<List<OfferComment>> getWarehouseComments(String id) async {
    final data = await _api.get(ApiEndpoints.whListingComments(id)) as List;
    return data.map((e) => OfferComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteWarehouseComment(String id, String commentId) =>
      _api.delete(ApiEndpoints.whListingCommentById(id, commentId));
}
