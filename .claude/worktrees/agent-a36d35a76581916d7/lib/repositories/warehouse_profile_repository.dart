import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/warehouse_auth_models.dart';

final warehouseProfileRepositoryProvider = Provider<WarehouseProfileRepository>((ref) {
  return WarehouseProfileRepository(ref.watch(apiClientProvider));
});

// بيانات المستودع الحالي (الملف الشخصي).
class WarehouseProfileRepository {
  WarehouseProfileRepository(this._api);
  final ApiClient _api;

  Future<WarehouseMe> getMe() async {
    final data = await _api.get(ApiEndpoints.whMe) as Map<String, dynamic>;
    return WarehouseMe.fromJson(data);
  }
}
