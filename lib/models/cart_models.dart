export 'package:tawrid_app/models/bonus_tier.dart';

import 'package:tawrid_app/models/bonus_tier.dart';
import 'package:tawrid_app/shared/utils/money.dart';

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

  /// نسبة البونص — الشكل القديم؛ فارغة في أسطر العروض ذات الشرائح.
  final double? bonusPercentage;

  /// الكمية المجانية المستحقّة على [quantity] بعد تركيب الشرائح.
  /// لا تدخل في [lineTotal]: مجانية لا تُحتسب ثمناً.
  final double freeQuantity;

  /// سلّم البونص المجمَّد وقت الإضافة — تُعرَض منه الشريحة التالية
  /// («أضف ٣ لتحصل على ١ مجاناً»).
  final List<BonusTier> bonusTiers;

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
    this.freeQuantity = 0,
    this.bonusTiers = const [],
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
      freeQuantity: (j['freeQuantity'] as num?)?.toDouble() ?? 0,
      bonusTiers: BonusTier.listFromJson(j['bonusTiers']),
      currency: j['currency'] as String? ?? 'SYP',
    );
  }

  bool get fromOffer => source == CartItemSource.offer;
  int get quantityInt => quantity.round();

  bool get hasFreeQuantity => freeQuantity > 0;

  /// كم تنقص الكمية لبلوغ الشريحة التالية — `null` حين لا شريحة أعلى.
  /// الشرائح تُركَّب، فالمقياس هو ما تبقّى بعد استهلاك ما أمكن منها.
  BonusTier? get nextTier {
    if (bonusTiers.isEmpty) return null;
    final sorted = [...bonusTiers]
      ..sort((a, b) => a.buyQuantity.compareTo(b.buyQuantity));
    for (final tier in sorted) {
      if (quantity < tier.buyQuantity) return tier;
    }
    return null;
  }
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

  /// عملة هذه المجموعة = عملة تسعير مستودعها. موحَّدة داخل المجموعة
  /// بالبناء: كل أسعار المستودع بعملة واحدة.
  final String currency;

  /// مجموع الكميات المجانية في المجموعة — شارة «+N مجاناً».
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

/// إجمالي عملة واحدة داخل السلّة.
class CartCurrencyTotal {
  final String currency;
  final double total;

  /// عدد المستودعات التي تُسعّر بهذه العملة في السلّة.
  final int warehouseCount;

  const CartCurrencyTotal({
    required this.currency,
    required this.total,
    this.warehouseCount = 0,
  });

  factory CartCurrencyTotal.fromJson(Map<String, dynamic> j) =>
      CartCurrencyTotal(
        currency: j['currency'] as String? ?? 'SYP',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        warehouseCount: j['warehouseCount'] as int? ?? 0,
      );

  String get label => formatMoneyWith(total, currency);
}

class Cart {
  final List<CartWarehouseGroup> groups;
  final int totalLines;
  final double totalQuantity;
  final int totalWarehouses;

  /// إجمالي السلّة **مفصولاً بالعملة** — لا رقمَ واحداً: المنصّة لا تحوّل،
  /// فجمع ليرةٍ على دولار يُنتج رقماً لا يدلّ على شيء. سلّةٌ من مستودع
  /// إدلبي وآخر حمصي تحمل سطرين، وتعرضهما الشاشة سطرين.
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

  /// العدد على شارة زر السلّة — أسطر لا كميات، فالشارة تقول «كم صنفاً».
  int get badgeCount => totalLines;

  /// هل في السلّة أكثر من عملة؟ حينها لا يصحّ سطر إجمالي واحد.
  bool get isMultiCurrency => totals.length > 1;

  /// مجموع الكميات المجانية عبر السلّة كلها — كميات تُجمَع بلا عملة.
  double get totalFreeQuantity =>
      groups.fold(0.0, (sum, g) => sum + g.totalFreeQuantity);

  /// إعادة احتساب الإجماليات من المجموعات — للتحديث التفاؤلي المحلي وحده،
  /// فكل استجابة من الخادم تحمل `totals` جاهزة.
  static List<CartCurrencyTotal> totalsFrom(
    List<CartWarehouseGroup> groups,
  ) {
    final byCurrency = <String, List<CartWarehouseGroup>>{};
    for (final g in groups) {
      byCurrency.putIfAbsent(g.currency, () => []).add(g);
    }
    final result =
        byCurrency.entries
            .map(
              (e) => CartCurrencyTotal(
                currency: e.key,
                total: e.value.fold(0.0, (s, g) => s + g.total),
                warehouseCount: e.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => a.currency.compareTo(b.currency));
    return result;
  }
}
