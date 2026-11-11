import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/warehouse_medicine_models.dart';

final warehouseMedicineRepositoryProvider = Provider<WarehouseMedicineRepository>((ref) {
  return WarehouseMedicineRepository(ref.watch(apiClientProvider));
});

class WarehouseMedicineRepository {
  WarehouseMedicineRepository(this._api);
  final ApiClient _api;

  /// [search] يُمرَّر إلى الخادم لا يُطبَّق محلياً: القائمة مُرقَّمة، وما
  /// لم يصل من صفحاتها لا يمكن البحث فيه على الجهاز.
  Future<List<WarehouseMedicine>> getMine({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.whMedicines, queryParameters: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': limit,
      'offset': offset,
    });
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => WarehouseMedicine.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [price] اختياري عند الإضافة، فلا تلزم خطوة تسعير منفصلة لمن يملكه الآن.
  Future<WarehouseMedicine> add(String catalogItemId, {double? price}) async {
    final data = await _api.post(ApiEndpoints.whMedicines, data: {
      'catalogItemId': catalogItemId,
      'price': ?price,
    }) as Map<String, dynamic>;
    return WarehouseMedicine.fromJson(data);
  }

  /// تعديل السعر وحده. [price] فارغاً يسحب السعر: يختفي الصنف من البحث
  /// المقارن ويبقى في «أدويتي» — سحب التسعير ليس حذفاً.
  Future<WarehouseMedicine> setPrice(String id, double? price) async {
    final data = await _api.patch(
      ApiEndpoints.whMedicinePrice(id),
      data: {'price': price},
    ) as Map<String, dynamic>;
    return WarehouseMedicine.fromJson(data);
  }

  Future<void> remove(String id) => _api.delete(ApiEndpoints.whMedicineById(id));
}
