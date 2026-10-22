import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/geo_models.dart';
import 'package:tawrid_app/repositories/geo_repository.dart';

final warehouseServiceAreaRepositoryProvider = Provider<WarehouseServiceAreaRepository>((ref) {
  return WarehouseServiceAreaRepository(ref.watch(apiClientProvider));
});

// مناطق خدمة المستودع الحالي — مُفلترة من كامل قائمة المحافظات/المدن إلى ما
// يخدمه هذا المستودع فقط: كل محافظة تحوي مدناً مخدومة تظهر، بمدنها المخدومة
// فقط. تُستهلك في منتقي مناطق استهداف العرض لمنع اختيار مناطق خارج التغطية.
final myServiceGovernoratesProvider = FutureProvider<List<Governorate>>((ref) async {
  final all = await ref.watch(governoratesProvider.future);
  final servedCityIds =
      (await ref.watch(warehouseServiceAreaRepositoryProvider).getMyServiceAreas()).toSet();

  final result = <Governorate>[];
  for (final g in all) {
    final served = g.cities.where((c) => servedCityIds.contains(c.id)).toList();
    if (served.isNotEmpty) {
      result.add(Governorate(id: g.id, name: g.name, cities: served));
    }
  }
  return result;
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
