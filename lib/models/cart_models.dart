// سلّة الصيدلية كما يُرجعها الخادم (`CartDto`) — مجمَّعة حسب المستودع، لأن
// **وحدة الإتمام مستودع واحد** لا السلّة كلها.
//
// لا تجميع محلّي هنا: كل مسار من مسارات السلّة يُعيد هذا الشكل كاملاً بعد
// التعديل، فتُرسَم الشاشة من الاستجابة مباشرة ولا تفترق عمّا في الخادم.

enum CartItemSource {
  offer(1),
  warehouseListing(2);

  const CartItemSource(this.code);
  final int code;

  static CartItemSource fromCode(int? code) => CartItemSource.values.firstWhere(
    (e) => e.code == code,
    orElse: () => CartItemSource.warehouseListing,
  );
}

class CartItem {
  final String id;
  final CartItemSource source;

  final String? salesOfferId;
  final String? salesOfferTitle;
  final String? salesOfferItemId;
  final String? warehouseMedicineId;

  final String medicineName;
  final String? catalogItemId;
  final String unit;
  final double quantity;

  /// السعر المجمَّد وقت الإضافة — هو ما يُرسَل كـ«السعر المتفق عليه».
  final double unitPrice;
  final double lineTotal;
  final double? bonusPercentage;
  final String currency;

  const CartItem({
    required this.id,
    required this.source,
    this.salesOfferId,
    this.salesOfferTitle,
    this.salesOfferItemId,
    this.warehouseMedicineId,
    required this.medicineName,
    this.catalogItemId,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.bonusPercentage,
    this.currency = 'SYP',
  });

  factory CartItem.fromJson(Map<String, dynamic> j) {
    final qty = (j['quantity'] as num?)?.toDouble() ?? 1;
    final price = (j['unitPrice'] as num?)?.toDouble() ?? 0;
    return CartItem(
      id: j['id'] as String,
      source: CartItemSource.fromCode(j['source'] as int?),
      salesOfferId: j['salesOfferId'] as String?,
      salesOfferTitle: j['salesOfferTitle'] as String?,
      salesOfferItemId: j['salesOfferItemId'] as String?,
      warehouseMedicineId: j['warehouseMedicineId'] as String?,
      medicineName: j['medicineName'] as String? ?? '',
      catalogItemId: j['catalogItemId'] as String?,
      unit: j['unit'] as String? ?? 'عبوة',
      quantity: qty,
      unitPrice: price,
      lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? price * qty,
      bonusPercentage: (j['bonusPercentage'] as num?)?.toDouble(),
      currency: j['currency'] as String? ?? 'SYP',
    );
  }

  bool get fromOffer => source == CartItemSource.offer;
  int get quantityInt => quantity.round();
}

class CartWarehouseGroup {
  final String supplyWarehouseId;
  final String warehouseName;
  final String city;
  final String governorate;

  /// حدّ هذا المستودع الأدنى للطلبية الواحدة (null = لا حدّ).
  final double? minimumOrderAmount;

  final double total;

  /// زر «إتمام طلبية هذا المستودع» يُعطَّل حين تكون false.
  final bool meetsMinimum;
  final double missingAmount;

  final String currency;
  final List<CartItem> items;

  const CartWarehouseGroup({
    required this.supplyWarehouseId,
    required this.warehouseName,
    this.city = '',
    this.governorate = '',
    this.minimumOrderAmount,
    required this.total,
    required this.meetsMinimum,
    this.missingAmount = 0,
    this.currency = 'SYP',
    required this.items,
  });

  factory CartWarehouseGroup.fromJson(Map<String, dynamic> j) {
    final items = ((j['items'] as List?) ?? const [])
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return CartWarehouseGroup(
      supplyWarehouseId: j['supplyWarehouseId'] as String,
      warehouseName: j['warehouseName'] as String? ?? '',
      city: j['city'] as String? ?? '',
      governorate: j['governorate'] as String? ?? '',
      minimumOrderAmount: (j['minimumOrderAmount'] as num?)?.toDouble(),
      total: (j['total'] as num?)?.toDouble() ?? 0,
      meetsMinimum: j['meetsMinimum'] as bool? ?? true,
      missingAmount: (j['missingAmount'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'SYP',
      items: items,
    );
  }

  /// «مستودع الشفاء — دمشق».
  String get warehouseLabel =>
      city.isEmpty ? warehouseName : '$warehouseName — $city';

  /// «صنف واحد» / «٣ أصناف» — سطر العدّاد فوق المجموعة.
  String get itemsLabel => switch (items.length) {
    1 => 'صنف واحد',
    2 => 'صنفان',
    _ => '${items.length} أصناف',
  };
}

class Cart {
  final List<CartWarehouseGroup> groups;
  final int totalLines;
  final double totalQuantity;
  final int totalWarehouses;
  final double grandTotal;
  final String currency;

  const Cart({
    this.groups = const [],
    this.totalLines = 0,
    this.totalQuantity = 0,
    this.totalWarehouses = 0,
    this.grandTotal = 0,
    this.currency = 'SYP',
  });

  static const empty = Cart();

  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
    groups: ((j['groups'] as List?) ?? const [])
        .map((e) => CartWarehouseGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalLines: j['totalLines'] as int? ?? 0,
    totalQuantity: (j['totalQuantity'] as num?)?.toDouble() ?? 0,
    totalWarehouses: j['totalWarehouses'] as int? ?? 0,
    grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'SYP',
  );

  bool get isEmpty => groups.isEmpty;

  /// العدد على شارة زر السلّة — أسطر لا كميات، فالشارة تقول «كم صنفاً».
  int get badgeCount => totalLines;
}
