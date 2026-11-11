import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/models/cart_models.dart';
import 'package:tawrid_app/repositories/cart_repository.dart';

/// سلّة الصيدلية — مرآة لما في الخادم لا نسخة محلية تتفرّع عنه.
///
/// كل عملية تُرسل إلى الخادم ويُستبدَل الحالة بالسلّة التي يُعيدها، فالعدّاد
/// والتجميع والحدّ الأدنى كلها من مصدر واحد. ولا تُخمَّن حالة متفائلة قبل
/// الاستجابة: السعر والتوافر يُعاد التحقق منهما في الخادم، فقد تُرفض إضافة
/// تبدو ناجحة محلياً.
final cartProvider = AsyncNotifierProvider<CartController, Cart>(
  CartController.new,
);

/// عدد أصناف السلّة لشارة الزر — صفر أثناء التحميل أو عند الفشل، فالشارة
/// تزيّن ولا تستحق إسقاط الشاشة.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).value?.badgeCount ?? 0;
});

class CartController extends AsyncNotifier<Cart> {
  @override
  Future<Cart> build() => ref.read(cartRepositoryProvider).getCart();

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  /// يشغّل عملية سلّة ويضع نتيجتها حالةً جديدة. يُعيد رمي الخطأ ليعرضه
  /// المستدعي كرسالة، مع إبقاء السلّة السابقة معروضة بدل تفريغ الشاشة.
  Future<Cart> _run(Future<Cart> Function() action) async {
    final previous = state.value;
    try {
      final cart = await action();
      state = AsyncData(cart);
      return cart;
    } catch (e, st) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(e, st);
      }
      rethrow;
    }
  }

  Future<Cart> refresh() => _run(() => _repo.getCart());

  /// إضافة صنف من نتيجة عرض — المعرّف المرسَل هو `salesOfferItemId`.
  Future<Cart> addOfferItem(String salesOfferItemId, {int quantity = 1}) =>
      _run(() => _repo.addItem(
            source: CartItemSource.offer,
            salesOfferItemId: salesOfferItemId,
            quantity: quantity,
          ));

  /// إضافة صنف من تسعير مباشر — المعرّف المرسَل هو `warehouseMedicineId`.
  Future<Cart> addWarehouseMedicine(String warehouseMedicineId, {int quantity = 1}) =>
      _run(() => _repo.addItem(
            source: CartItemSource.warehouseListing,
            warehouseMedicineId: warehouseMedicineId,
            quantity: quantity,
          ));

  /// الكمية صفر أو أقل تحذف السطر — الإنقاص إلى صفر حذف لا خطأ.
  Future<Cart> setQuantity(String itemId, int quantity) =>
      _run(() => _repo.setQuantity(itemId, quantity));

  Future<Cart> removeItem(String itemId) => _run(() => _repo.removeItem(itemId));

  Future<Cart> clearWarehouse(String warehouseId) =>
      _run(() => _repo.clearWarehouse(warehouseId));

  Future<Cart> clear() => _run(() => _repo.clear());

  /// إتمام مجموعة مستودع واحدة. السلّة العائدة تُستبدَل بها الحالة، فتختفي
  /// المجموعة المُرسَلة وتبقى البقية — بلا طلب ثانٍ ولا تخمين محلّي.
  Future<CartCheckoutResult> checkout(
    String warehouseId, {
    String? notes,
    DateTime? expectedDeliveryDate,
  }) async {
    final previous = state.value;
    try {
      final result = await _repo.checkout(
        warehouseId,
        notes: notes,
        expectedDeliveryDate: expectedDeliveryDate,
      );
      state = AsyncData(result.cart);
      return result;
    } catch (e) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}
