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

  Future<List<WarehouseMedicine>> getMine() async {
    final data = await _api.get(ApiEndpoints.whMedicines) as List;
    return data.map((e) => WarehouseMedicine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WarehouseMedicine> add(String catalogItemId) async {
    final data = await _api.post(ApiEndpoints.whMedicines, data: {'catalogItemId': catalogItemId})
        as Map<String, dynamic>;
    return WarehouseMedicine.fromJson(data);
  }

  Future<void> remove(String id) => _api.delete(ApiEndpoints.whMedicineById(id));
}
