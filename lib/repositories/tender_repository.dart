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
    final raw = await _api.get(ApiEndpoints.phTenders,
        queryParameters: {'limit': limit, 'offset': offset});
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => TenderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [asDraft] يحفظ الطلب بلا نشر: لا يصل أي مستودع ولا يُرسَل إشعار،
  /// والنشر لاحقاً عبر [publishTender].
  Future<TenderDetail> createTender({
    required String title,
    String? description,
    required DateTime expiresAt,
    required List<TenderItem> items,
    bool asDraft = false,
  }) async {
    final data = await _api.post(ApiEndpoints.phTenders, data: {
      'title': title,
      'description': description,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'items': items.map((e) => e.toCreateJson()).toList(),
      'asDraft': asDraft,
    }) as Map<String, dynamic>;
    return TenderDetail.fromJson(data);
  }

  /// نشر مسودة — تتحوّل إلى «مفتوحة» وتصل المستودعات التي تخدم منطقتك.
  Future<TenderDetail> publishTender(String id) async {
    final data =
        await _api.post(ApiEndpoints.phTenderPublish(id)) as Map<String, dynamic>;
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
    final raw = await _api.get(ApiEndpoints.whTendersOpen,
        queryParameters: {'limit': limit, 'offset': offset});
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => TenderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  // تفاصيل طلب تسعير (أصنافه) قبل التقدّم بعرض سعر — بلا أي معلومة عن المنافسين.
  Future<TenderDetail> getTenderDetailsForWarehouse(String tenderId) async {
    final data = await _api.get(ApiEndpoints.whTenderById(tenderId)) as Map<String, dynamic>;
    return TenderDetail.fromJson(data);
  }

  Future<List<MyTenderOfferSummary>> getMyOffers({int limit = 20, int offset = 0}) async {
    final raw = await _api.get(ApiEndpoints.whMyOffers,
        queryParameters: {'limit': limit, 'offset': offset});
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => MyTenderOfferSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// تقديم عرض سعر — أو تعديله ما دام الطلب مفتوحاً (الخادم يستبدل
  /// العرض القائم للمستودع نفسه)، أو حفظه مسودةً لا تصل الصيدلية.
  Future<TenderOffer> submitOffer({
    required String tenderId,
    required int offerType, // TenderOfferType.code → quotationType
    String? notes,
    required List<Map<String, dynamic>> items, // {tenderItemId, unitPrice?, bonusPercentage?, extraBonus?, notes?}
    bool asDraft = false,
  }) async {
    // الخادم يتوقّع quotationType و quotationRequestItemId بعد إعادة التسمية.
    final payloadItems = items.map((i) {
      final m = Map<String, dynamic>.from(i);
      if (m.containsKey('tenderItemId')) {
        m['quotationRequestItemId'] = m.remove('tenderItemId');
      }
      return m;
    }).toList();

    final data = await _api.post(ApiEndpoints.whTenderSubmit(tenderId), data: {
      'quotationType': offerType,
      'notes': notes,
      'items': payloadItems,
      'asDraft': asDraft,
    }) as Map<String, dynamic>;
    return TenderOffer.fromJson(data);
  }
}
