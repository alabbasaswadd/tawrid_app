import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/announcement_models.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(apiClientProvider));
});

class AnnouncementRepository {
  AnnouncementRepository(this._api);
  final ApiClient _api;

  // ── جهة المستودع ─────────────────────────────────────────────────────
  Future<List<WarehouseAnnouncement>> getMyAnnouncements() async {
    final raw = await _api.get(ApiEndpoints.whAnnouncements);
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => WarehouseAnnouncement.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createAnnouncement({
    required String title,
    String? body,
    required double discountValue,
    required DateTime validUntil,
  }) async {
    await _api.post(ApiEndpoints.whAnnouncements, data: {
      'title': title,
      'body': body,
      'discountType': 1, // InvoicePercentage
      'discountValue': discountValue,
      'validUntil': validUntil.toUtc().toIso8601String(),
    });
  }

  // ── جهة الصيدلي ──────────────────────────────────────────────────────
  Future<WarehouseAnnouncement?> getActiveAnnouncement(String warehouseId) async {
    try {
      final data = await _api.get(ApiEndpoints.phWarehouseAnnouncement(warehouseId));
      if (data == null) return null;
      return WarehouseAnnouncement.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
