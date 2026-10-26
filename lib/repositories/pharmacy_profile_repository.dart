import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/pharmacy_auth_models.dart';

final pharmacyProfileRepositoryProvider = Provider<PharmacyProfileRepository>(
  (ref) => PharmacyProfileRepository(ref.watch(apiClientProvider)),
);

// الصيدلية الحالية — الاسم للترحيب، والمحافظة/المدينة لمعرفة ما يغطّي
// منطقتها. يقابل `warehouseMeProvider` في جهة المستودع.
final pharmacyMeProvider = FutureProvider<PharmacyMe>(
  (ref) => ref.watch(pharmacyProfileRepositoryProvider).getMe(),
);

class PharmacyProfileRepository {
  PharmacyProfileRepository(this._api);
  final ApiClient _api;

  Future<PharmacyMe> getMe() async {
    final data = await _api.get(ApiEndpoints.phMe) as Map<String, dynamic>;
    return PharmacyMe.fromJson(data);
  }
}
