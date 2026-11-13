/// عملة المنصّة الافتراضية.
///
/// طلبية التوريد لا تحمل عملةً في الخادم (`SupplyOrderDetailDto` بلا حقل
/// Currency) بينما العرض يحملها، فالطلبيات تُعرض بهذه. إن دعت الحاجة إلى
/// عملات متعددة في الطلبيات فالحقل يُضاف في الخادم أولاً، لا يُخمَّن هنا.
const String kPlatformCurrency = 'SYP';

// صياغة المبالغ. الأرقام هنا تُقرأ داخل قرار شراء، و«530000» بلا فواصل
// تُقرأ خطأً — لذا فاصل آلاف دائماً، وبلا كسور لأن الليرة لا تُكسَّر عملياً.
String formatMoney(num value) {
  final negative = value < 0;
  final s = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return negative ? '-$buf' : buf.toString();
}

/// «530,000 ل.س» / «2.25 $» — المبلغ مع رمز العملة.
/// الليرة بلا كسور؛ العملات الأجنبية بمنزلتين عشريتين.
String formatMoneyWith(num value, String currency) {
  final sym = currencySymbol(currency);
  if (currency.toUpperCase() == 'SYP') return '${formatMoney(value)} $sym';
  return '${value.toStringAsFixed(2)} $sym';
}

/// «12» / «2.5» / «10» — كمية بلا أصفار لاحقة.
String formatQuantity(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}

/// رمز العملة بالعربية؛ ما لا يُعرف يُعرض كما جاء من الخادم.
String currencySymbol(String code) => switch (code.toUpperCase()) {
      'SYP' => 'ل.س',
      'USD' => '\$',
      'EUR' => '€',
      'TRY' => '₺',
      _ => code,
    };
