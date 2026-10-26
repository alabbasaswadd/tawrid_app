import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';

final supplyOrderRepositoryProvider = Provider<SupplyOrderRepository>((ref) {
  return SupplyOrderRepository(ref.watch(apiClientProvider));
});

class SupplyOrderRepository {
  SupplyOrderRepository(this._api);
  final ApiClient _api;

  // ── جهة الصيدلي ──────────────────────────────────────────────────────
  Future<List<SupplyOrderSummary>> getMyOrders({
    SupplyOrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.phOrders, queryParameters: {
      if (status != null) 'status': status.code,
      'limit': limit,
      'offset': offset,
    });
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => SupplyOrderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SupplyOrderDetail> createOrder({
    required String supplyWarehouseId,
    required List<SupplyOrderItem> items,
    String? notes,
    DateTime? expectedDeliveryDate,
  }) async {
    final data = await _api.post(ApiEndpoints.phOrders, data: {
      'supplyWarehouseId': supplyWarehouseId,
      'items': items.map((e) => e.toCreateJson()).toList(),
      'notes': notes,
      'expectedDeliveryDate': expectedDeliveryDate?.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;
    return SupplyOrderDetail.fromJson(data);
  }

  Future<SupplyOrderDetail> getOrderById(String id) async {
    final data = await _api.get(ApiEndpoints.phOrderById(id)) as Map<String, dynamic>;
    return SupplyOrderDetail.fromJson(data);
  }

  Future<List<StatusHistoryItem>> getOrderHistory(String id) async {
    final raw = await _api.get(ApiEndpoints.phOrderHistory(id));
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => StatusHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancelOrder(String id) => _api.post(ApiEndpoints.phOrderCancel(id));

  Future<GenerateInvoiceResult> generateInvoice(String id) async {
    final data = await _api.post(ApiEndpoints.phOrderGenerateInvoice(id)) as Map<String, dynamic>;
    return GenerateInvoiceResult.fromJson(data);
  }

  // ── جهة المستودع ─────────────────────────────────────────────────────
  Future<List<SupplyOrderSummary>> getWarehouseOrders({
    SupplyOrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.whOrders, queryParameters: {
      if (status != null) 'status': status.code,
      'limit': limit,
      'offset': offset,
    });
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => SupplyOrderSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SupplyOrderDetail> getWarehouseOrderById(String id) async {
    final data = await _api.get(ApiEndpoints.whOrderById(id)) as Map<String, dynamic>;
    return SupplyOrderDetail.fromJson(data);
  }

  /// سجلّ حالات الطلب كما يراه المستودع — مسارٌ مختلف عن مسار الصيدلي،
  /// وتوكنٌ مختلف يختاره الـinterceptor من بادئة «/warehouse/».
  Future<List<StatusHistoryItem>> getWarehouseOrderHistory(String id) async {
    final raw = await _api.get(ApiEndpoints.whOrderHistory(id));
    final data = ApiClient.itemsOf(raw);
    return data.map((e) => StatusHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateOrderStatus(String id, SupplyOrderStatus newStatus, {String? comment}) {
    return _api.put(ApiEndpoints.whOrderStatus(id), data: {
      'newStatus': newStatus.code,
      'comment': comment,
    });
  }
}
