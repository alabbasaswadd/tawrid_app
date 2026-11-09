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
  /// بعملة [pricingCurrency].
  final double? minimumOrderAmount;

  /// عملة كل أسعار المستودع — مشتقّة من محافظته عند التسجيل وقابلة
  /// للتجاوز. الخادم يرفض تبديلها ما دام هناك عرض بيع فعّال، لأن أسعار
  /// «أدويتي» أرقامٌ بلا عملة مخزَّنة معها فتبديلها يُعيد تسميتها كلها.
  final String pricingCurrency;

  const WarehouseSettings({
    this.minimumOrderAmount,
    this.pricingCurrency = 'SYP',
  });

  factory WarehouseSettings.fromJson(Map<String, dynamic> j) =>
      WarehouseSettings(
        minimumOrderAmount: (j['minimumOrderAmount'] as num?)?.toDouble(),
        pricingCurrency: j['pricingCurrency'] as String? ?? 'SYP',
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
  ///
  /// [pricingCurrency] فارغاً = **لا تغيير** (لا إعادة إلى الافتراضي):
  /// من أرسل الحدّ الأدنى وحده لا يقصد تصفير عملته.
  Future<WarehouseSettings> update({
    double? minimumOrderAmount,
    String? pricingCurrency,
  }) async {
    final data =
        await _api.put(
              ApiEndpoints.whSettings,
              data: {
                'minimumOrderAmount': minimumOrderAmount,
                'pricingCurrency': pricingCurrency,
              },
            )
            as Map<String, dynamic>;
    return WarehouseSettings.fromJson(data);
  }
}
