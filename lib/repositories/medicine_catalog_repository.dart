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

  Future<List<MedicineCatalogItem>> search({String? name, int limit = 30}) async {
    final data = await _api.get(ApiEndpoints.catalogSearch, queryParameters: {
      'name': ?name,
      'limit': limit,
    }) as List;
    return data.map((e) => MedicineCatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
