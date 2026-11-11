import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/warehouse_models.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepository(ref.watch(apiClientProvider));
});

// تصفّح المستودعات المُوّرِدة النشطة (جهة الصيدلي) — لاختيار مستودع عند
// إنشاء طلبية توريد.
class WarehouseRepository {
  WarehouseRepository(this._api);
  final ApiClient _api;

  Future<List<WarehousePicker>> getActiveWarehouses() async {
    final data = await _api.get(ApiEndpoints.supplyWarehouses) as List;
    return data.map((e) => WarehousePicker.fromJson(e as Map<String, dynamic>)).toList();
  }
}
