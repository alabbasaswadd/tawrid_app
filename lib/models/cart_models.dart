// سلّة الصيدلية كما يُرجعها الخادم (`CartDto`) — مجمَّعة حسب المستودع، لأن
// **وحدة الإتمام مستودع واحد** لا السلّة كلها.
//
// لا تجميع محلّي هنا: كل مسار من مسارات السلّة يُعيد هذا الشكل كاملاً بعد
// التعديل، فتُرسَم الشاشة من الاستجابة مباشرة ولا تفترق عمّا في الخادم.

class CartBonusTier {
  final double buyQuantity;
  final double freeQuantity;
  final String label;

  const CartBonusTier({
    required this.buyQuantity,
    required this.freeQuantity,
    required this.label,
  });

  factory CartBonusTier.fromJson(Map<String, dynamic> j) => CartBonusTier(
        buyQuantity: (j['buyQuantity'] as num).toDouble(),
        freeQuantity: (j['freeQuantity'] as num).toDouble(),
        label: j['label'] as String,
      );
}

class CartCurrencyTotal {
  final String currency;
  final double total;
  final int warehouseCount;

  const CartCurrencyTotal({
    required this.currency,
    required this.total,
    required this.warehouseCount,
  });

  factory CartCurrencyTotal.fromJson(Map<String, dynamic> j) => CartCurrencyTotal(
        currency: j['currency'] as String,
        total: (j['total'] as num).toDouble(),
        warehouseCount: j['warehouseCount'] as int? ?? 1,
      );
}

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
  final double freeQuantity;
  final List<CartBonusTier> bonusTiers;
  final String currency;
  final DateTime? createdOn;

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
    this.freeQuantity = 0,
    this.bonusTiers = const [],
    this.currency = 'SYP',
    this.createdOn,
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
      freeQuantity: (j['freeQuantity'] as num?)?.toDouble() ?? 0,
      bonusTiers: ((j['bonusTiers'] as List?) ?? [])
          .map((e) => CartBonusTier.fromJson(e as Map<String, dynamic>))
          .toList(),
      currency: j['currency'] as String? ?? 'SYP',
      createdOn: j['createdOn'] != null
          ? DateTime.parse(j['createdOn'] as String)
          : null,
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
  final double totalFreeQuantity;
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
    this.totalFreeQuantity = 0,
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
      totalFreeQuantity: (j['totalFreeQuantity'] as num?)?.toDouble() ?? 0,
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

  /// إجماليات مفصولة بالعملة — الباك إند لا يجمع عملات مختلفة في رقم واحد.
  final List<CartCurrencyTotal> totals;

  const Cart({
    this.groups = const [],
    this.totalLines = 0,
    this.totalQuantity = 0,
    this.totalWarehouses = 0,
    this.totals = const [],
  });

  static const empty = Cart();

  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
    groups: ((j['groups'] as List?) ?? const [])
        .map((e) => CartWarehouseGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalLines: j['totalLines'] as int? ?? 0,
    totalQuantity: (j['totalQuantity'] as num?)?.toDouble() ?? 0,
    totalWarehouses: j['totalWarehouses'] as int? ?? 0,
    totals: ((j['totals'] as List?) ?? const [])
        .map((e) => CartCurrencyTotal.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  bool get isEmpty => groups.isEmpty;

  /// الإجمالي الكلي — صحيح فقط إذا كانت السلّة بعملة واحدة.
  double get grandTotal => totals.fold(0, (sum, t) => sum + t.total);

  /// عملة السلّة إذا كانت بعملة واحدة، وإلا 'MIXED'.
  String get currency =>
      totals.length == 1 ? totals.first.currency : (totals.isEmpty ? 'SYP' : 'MIXED');

  /// العدد على شارة زر السلّة — أسطر لا كميات، فالشارة تقول «كم صنفاً».
  int get badgeCount => totalLines;
}
