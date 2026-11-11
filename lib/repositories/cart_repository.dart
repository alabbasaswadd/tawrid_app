import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/cart_models.dart';
import 'package:tawrid_app/models/supply_order_models.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

/// نتيجة إتمام مجموعة مستودع: الطلبية المُنشأة + السلّة بعد خصم مجموعتها،
/// في استجابة واحدة فلا طلب ثانٍ لإعادة رسم الشاشة.
class CartCheckoutResult {
  final SupplyOrderDetail order;
  final Cart cart;
  const CartCheckoutResult({required this.order, required this.cart});
}

/// السلّة محفوظة على الخادم: كل عملية هنا تُعيد السلّة كاملةً بعد التعديل،
/// مجمَّعةً حسب المستودع كما تحتاجها الشاشة.
class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Future<Cart> getCart() async {
    final data = await _api.get(ApiEndpoints.phCart) as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  /// الإضافة ترسل مرجع المصدر والكمية فقط — السعر يُشتقّ في الخادم من
  /// المصدر بعد إعادة التحقق من أن الصيدلي يراه فعلاً.
  Future<Cart> addItem({
    required CartItemSource source,
    String? salesOfferItemId,
    String? warehouseMedicineId,
    int quantity = 1,
  }) async {
    final data = await _api.post(ApiEndpoints.phCartItems, data: {
      'source': source.code,
      'salesOfferItemId': ?salesOfferItemId,
      'warehouseMedicineId': ?warehouseMedicineId,
      'quantity': quantity,
    }) as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  /// الكمية صفر أو أقل تحذف السطر — الإنقاص إلى صفر حذف لا خطأ.
  Future<Cart> setQuantity(String itemId, int quantity) async {
    final data = await _api.patch(
      ApiEndpoints.phCartItemById(itemId),
      data: {'quantity': quantity},
    ) as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  Future<Cart> removeItem(String itemId) async {
    final data = await _api.deleteJson(ApiEndpoints.phCartItemById(itemId))
        as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  Future<Cart> clearWarehouse(String warehouseId) async {
    final data = await _api.deleteJson(ApiEndpoints.phCartWarehouse(warehouseId))
        as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  Future<Cart> clear() async {
    final data = await _api.deleteJson(ApiEndpoints.phCart) as Map<String, dynamic>;
    return Cart.fromJson(data);
  }

  /// إتمام مجموعة مستودع واحدة كطلبية. بقية المجموعات تبقى في السلّة
  /// لتُكمَل لاحقاً — لا ترابط بينها.
  Future<CartCheckoutResult> checkout(
    String warehouseId, {
    String? notes,
    DateTime? expectedDeliveryDate,
  }) async {
    final data = await _api.post(ApiEndpoints.phCartCheckout(warehouseId), data: {
      'notes': notes,
      'expectedDeliveryDate': expectedDeliveryDate?.toUtc().toIso8601String(),
    }) as Map<String, dynamic>;

    return CartCheckoutResult(
      order: SupplyOrderDetail.fromJson(data['order'] as Map<String, dynamic>),
      cart: Cart.fromJson(data['cart'] as Map<String, dynamic>),
    );
  }
}
