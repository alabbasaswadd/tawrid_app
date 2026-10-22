import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';

final warehouseServiceAreaRepositoryProvider = Provider<WarehouseServiceAreaRepository>((ref) {
  return WarehouseServiceAreaRepository(ref.watch(apiClientProvider));
});

class WarehouseServiceAreaRepository {
  WarehouseServiceAreaRepository(this._api);
  final ApiClient _api;

  Future<List<String>> getMyServiceAreas() async {
    final data = await _api.get(ApiEndpoints.whServiceAreas) as List;
    return data.cast<String>();
  }

  Future<void> setServiceAreas(List<String> cityIds) =>
      _api.put(ApiEndpoints.whServiceAreas, data: {'cityIds': cityIds});
}
