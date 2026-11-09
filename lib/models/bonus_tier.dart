// شريحة بونص كمّية — نوعٌ مشترك بين العروض ونتائج البحث والسلّة
// والطلبيات، فيعيش وحده لا داخل أحدها.

/// شريحة بونص كمّية: «اشترِ [buyQuantity] واحصل على [freeQuantity] مجاناً».
/// [label] يأتي جاهزاً من الخادم («10 + 5») فلا تُصاغ الأرقام في موضعين.
class BonusTier {
  final double buyQuantity;
  final double freeQuantity;
  final String label;

  const BonusTier({
    required this.buyQuantity,
    required this.freeQuantity,
    required this.label,
  });

  factory BonusTier.fromJson(Map<String, dynamic> j) {
    final buy = (j['buyQuantity'] as num?)?.toDouble() ?? 0;
    final free = (j['freeQuantity'] as num?)?.toDouble() ?? 0;
    return BonusTier(
      buyQuantity: buy,
      freeQuantity: free,
      label: j['label'] as String? ?? '$buy + $free',
    );
  }

  static List<BonusTier> listFromJson(Object? raw) =>
      ((raw as List?) ?? const [])
          .map((e) => BonusTier.fromJson(e as Map<String, dynamic>))
          .toList();

  Map<String, dynamic> toCreateJson() => {
    'buyQuantity': buyQuantity,
    'freeQuantity': freeQuantity,
  };
}
