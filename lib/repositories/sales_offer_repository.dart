import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';

final salesOfferRepositoryProvider = Provider<SalesOfferRepository>((ref) {
  return SalesOfferRepository(ref.watch(apiClientProvider));
});

class SalesOfferRepository {
  SalesOfferRepository(this._api);
  final ApiClient _api;

  // ── جهة الصيدلي (تصفّح) ──────────────────────────────────────────────
  Future<List<SalesOfferSummary>> getAvailableOffers({int limit = 20, int offset = 0}) async {
    final data = await _api.get(ApiEndpoints.phOffers,
        queryParameters: {'limit': limit, 'offset': offset}) as List;
    return data.map((e) => SalesOfferSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SalesOfferDetail> getOfferById(String id) async {
    final data = await _api.get(ApiEndpoints.phOfferById(id)) as Map<String, dynamic>;
    return SalesOfferDetail.fromJson(data);
  }

  Future<OfferComment> addPharmacyComment(String id, String content) async {
    final data = await _api.post(ApiEndpoints.phOfferComments(id), data: {'content': content})
        as Map<String, dynamic>;
    return OfferComment.fromJson(data);
  }

  Future<List<OfferComment>> getPharmacyComments(String id) async {
    final data = await _api.get(ApiEndpoints.phOfferComments(id)) as List;
    return data.map((e) => OfferComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deletePharmacyComment(String id, String commentId) =>
      _api.delete(ApiEndpoints.phOfferCommentById(id, commentId));

  // ── جهة المستودع ─────────────────────────────────────────────────────
  Future<SalesOfferDetail> createOffer({
    required String title,
    String? description,
    required SalesOfferType offerType,
    required DateTime startsAt,
    required DateTime expiresAt,
    String? targetGovernorate,
    String? targetCity,
    bool isPublicInRegion = false,
    double? upfrontPercentage,
    int? paymentPeriodDays,
    String? consignmentTerms,
    required List<SalesOfferItem> items,
    List<String>? targetTenantIds,
  }) async {
    final data = await _api.post(ApiEndpoints.whSalesOffers, data: {
      'title': title,
      'description': description,
      'offerType': offerType.code,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'targetGovernorate': targetGovernorate,
      'targetCity': targetCity,
      'isPublicInRegion': isPublicInRegion,
      'upfrontPercentage': upfrontPercentage,
      'paymentPeriodDays': paymentPeriodDays,
      'consignmentTerms': consignmentTerms,
      'items': items.map((e) => e.toCreateJson()).toList(),
      'targetTenantIds': targetTenantIds,
    }) as Map<String, dynamic>;
    return SalesOfferDetail.fromJson(data);
  }

  Future<List<SalesOfferSummary>> getMyOffers({
    SalesOfferStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.get(ApiEndpoints.whSalesOffers, queryParameters: {
      if (status != null) 'status': status.code,
      'limit': limit,
      'offset': offset,
    }) as List;
    return data.map((e) => SalesOfferSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SalesOfferDetail> getWarehouseOfferById(String id) async {
    final data = await _api.get(ApiEndpoints.whSalesOfferById(id)) as Map<String, dynamic>;
    return SalesOfferDetail.fromJson(data);
  }

  Future<void> publishOffer(String id) => _api.post(ApiEndpoints.whSalesOfferPublish(id));

  Future<void> cancelOffer(String id) => _api.post(ApiEndpoints.whSalesOfferCancel(id));

  Future<void> addTargets(String id, List<String> tenantIds) =>
      _api.post(ApiEndpoints.whSalesOfferTargets(id), data: {'tenantIds': tenantIds});

  Future<OfferComment> addWarehouseComment(String id, String content) async {
    final data = await _api.post(ApiEndpoints.whSalesOfferComments(id), data: {'content': content})
        as Map<String, dynamic>;
    return OfferComment.fromJson(data);
  }

  Future<List<OfferComment>> getWarehouseComments(String id) async {
    final data = await _api.get(ApiEndpoints.whSalesOfferComments(id)) as List;
    return data.map((e) => OfferComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteWarehouseComment(String id, String commentId) =>
      _api.delete(ApiEndpoints.whSalesOfferCommentById(id, commentId));
}
