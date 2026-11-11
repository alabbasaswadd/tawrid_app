import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/medicine_catalog_models.dart';

final medicineCatalogRepositoryProvider = Provider<MedicineCatalogRepository>((ref) {
  return MedicineCatalogRepository(ref.watch(apiClientProvider));
});

// عام بلا توكن — مكتبة الأدوية المركزية.
class MedicineCatalogRepository {
  MedicineCatalogRepository(this._api);
  final ApiClient _api;

  // بحث أونلاين بالاسم/الباركود مع فلترة اختيارية بالشركة وترقيم صفحات عبر offset.
  Future<List<MedicineCatalogItem>> search({
    String? name,
    String? manufacturer,
    int limit = 30,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.catalogSearch, queryParameters: {
      'name': ?name,
      'manufacturer': ?manufacturer,
      'limit': limit,
      'offset': offset,
    });
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => MedicineCatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // أسماء الشركات المصنّعة المميّزة — لتعبئة فلتر الشركة.
  Future<List<String>> getManufacturers() async {
    final raw = await _api.get(ApiEndpoints.catalogManufacturers);
    final data = ApiClient.itemsOf(raw);
    return data.cast<String>();
  }
}
