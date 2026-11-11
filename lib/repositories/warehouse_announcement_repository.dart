import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/warehouse_models.dart';

final warehouseAnnouncementRepositoryProvider =
    Provider<WarehouseAnnouncementRepository>((ref) {
  return WarehouseAnnouncementRepository(ref.watch(apiClientProvider));
});

class WarehouseAnnouncementRepository {
  WarehouseAnnouncementRepository(this._api);
  final ApiClient _api;

  Future<void> createAnnouncement({
    required String title,
    String? body,
    required int discountType,
    required double discountValue,
    required DateTime validUntil,
  }) async {
    await _api.post(ApiEndpoints.whAnnouncements, data: {
      'title': title,
      'body': body,
      'discountType': discountType,
      'discountValue': discountValue,
      'validUntil': validUntil.toUtc().toIso8601String(),
    });
  }

  Future<List<WarehouseAnnouncement>> getWarehouseAnnouncements() async {
    final raw = await _api.get(ApiEndpoints.whAnnouncements);
    final data = ApiClient.itemsOf(raw);
    return data
        .map((e) => WarehouseAnnouncement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WarehouseAnnouncement?> getActiveAnnouncement(String warehouseId) async {
    final data = await _api.get(ApiEndpoints.phWarehouseAnnouncement(warehouseId));
    if (data == null) return null;
    return WarehouseAnnouncement.fromJson(data as Map<String, dynamic>);
  }
}
