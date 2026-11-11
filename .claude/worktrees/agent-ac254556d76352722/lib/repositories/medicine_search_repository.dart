import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';

final medicineSearchRepositoryProvider = Provider<MedicineSearchRepository>((ref) {
  return MedicineSearchRepository(ref.watch(apiClientProvider));
});

/// صفحة من نتائج البحث المقارن — يحتاج العميل العدد الكلي ليعرف متى يتوقّف
/// عن طلب المزيد.
class MedicineSearchPage {
  final List<MedicineSearchResult> items;
  final int totalCount;
  const MedicineSearchPage({required this.items, required this.totalCount});
}

class MedicineSearchRepository {
  MedicineSearchRepository(this._api);
  final ApiClient _api;

  /// البحث المقارن: أصناف العروض السارية + التسعير المباشر من المستودعات
  /// التي تخدم مدينة الصيدلية، في قائمة واحدة مرتَّبة في الخادم.
  Future<MedicineSearchPage> search({
    String? name,
    String? catalogItemId,
    /// يحصر البحث بمستودع واحد — بحث «داخل هذا المستودع» من ملفه.
    String? warehouseId,
    MedicineSearchSource source = MedicineSearchSource.all,
    MedicineSearchSort sort = MedicineSearchSort.byDefault,
    int limit = 20,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.phMedicinePriceSearch, queryParameters: {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'catalogItemId': ?catalogItemId,
      'warehouseId': ?warehouseId,
      'source': source.code,
      'sort': sort.code,
      'limit': limit,
      'offset': offset,
    });

    return MedicineSearchPage(
      items: ApiClient.itemsOf(raw)
          .map((e) => MedicineSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: ApiClient.totalOf(raw),
    );
  }
}
