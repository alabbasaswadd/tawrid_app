import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';

final warehouseSettingsRepositoryProvider =
    Provider<WarehouseSettingsRepository>((ref) {
      return WarehouseSettingsRepository(ref.watch(apiClientProvider));
    });

/// إعدادات الطلبيات التي يضبطها كل مستودع لنفسه.
class WarehouseSettings {
  /// حدّ أدنى لقيمة الطلبية الواحدة؛ null = لا حدّ أدنى.
  final double? minimumOrderAmount;

  const WarehouseSettings({this.minimumOrderAmount});

  factory WarehouseSettings.fromJson(Map<String, dynamic> j) => WarehouseSettings(
    minimumOrderAmount: (j['minimumOrderAmount'] as num?)?.toDouble(),
  );
}

class WarehouseSettingsRepository {
  WarehouseSettingsRepository(this._api);
  final ApiClient _api;

  Future<WarehouseSettings> get() async {
    final data = await _api.get(ApiEndpoints.whSettings) as Map<String, dynamic>;
    return WarehouseSettings.fromJson(data);
  }

  /// [minimumOrderAmount] فارغاً يرفع الحدّ فيُقبل أي مبلغ.
  Future<WarehouseSettings> update({double? minimumOrderAmount}) async {
    final data = await _api.put(
      ApiEndpoints.whSettings,
      data: {'minimumOrderAmount': minimumOrderAmount},
    ) as Map<String, dynamic>;
    return WarehouseSettings.fromJson(data);
  }
}
