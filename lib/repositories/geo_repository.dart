import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/geo_models.dart';

final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepository(ref.watch(apiClientProvider));
});

class GeoRepository {
  GeoRepository(this._api);
  final ApiClient _api;

  // عام بلا توكن — يغذّي واجهة اختيار مناطق التغطية بالكامل من الخادم،
  // فإضافة محافظة/مدينة جديدة لا تحتاج تحديث هذا التطبيق.
  Future<List<Governorate>> getGovernorates() async {
    final raw = await _api.get(ApiEndpoints.geoGovernorates);
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => Governorate.fromJson(e as Map<String, dynamic>)).toList();
  }
}

// قائمة المحافظات/المدن — تُجلَب مرّة وتُشارَك بين كل الشاشات التي تحتاجها
// (تسجيل الصيدلي، تسجيل المستودع، مناطق التخديم...).
final governoratesProvider = FutureProvider<List<Governorate>>((ref) {
  return ref.watch(geoRepositoryProvider).getGovernorates();
});
