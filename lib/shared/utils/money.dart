/// صياغة المبالغ.
///
/// الأرقام هنا تُقرأ داخل قرار شراء، و«530000» بلا فواصل تُقرأ خطأً — لذا
/// فاصل آلاف دائماً.
///
/// والكسور **تتبع العملة** لا ذوق الشاشة: الليرة لا تُكسَّر عملياً فتُعرض
/// صحيحة، أما الدولار فنشرات المستودعات تُسعّر به بمنزلتين (2.25 · 0.87 ·
/// 0.35) — وتدويرها يحوّل 0.35 إلى «صفر» و0.87 إلى «واحد»، فيصير السعر
/// المعروض سعراً آخر. لذلك لا يُصاغ مبلغ بلا عملة: الدوالّ كلها تطلبها.
library;

/// عدد المنازل العشرية المعروضة لكل عملة.
///
/// عملة لا نعرفها تأخذ منزلتين لا صفراً: الكسر الزائد يُقرأ، أما المبتور
/// فيكذب.
int currencyDecimals(String code) => switch (code.toUpperCase()) {
  'SYP' => 0,
  _ => 2,
};

/// «530,000» · «2.25» — الرقم وحده بمنازل عملته وبفاصل آلاف.
/// لجداول تحمل العملة في ترويستها (ومنها جدول الـ PDF) فلا تكرّرها كل سطر.
String formatAmount(num value, String currency) =>
    _group(value, currencyDecimals(currency));

/// «530,000 ل.س» · «2.25 $» — المبلغ مع رمز عملته.
String formatMoneyWith(num value, String currency) =>
    '${formatAmount(value, currency)} ${currencySymbol(currency)}';

/// رمز العملة بالعربية؛ ما لا يُعرف يُعرض كما جاء من الخادم.
String currencySymbol(String code) => switch (code.toUpperCase()) {
  'SYP' => 'ل.س',
  'USD' => '\$',
  'EUR' => '€',
  'TRY' => '₺',
  _ => code,
};

/// اسم العملة كاملاً — لقوائم الاختيار وشاشات الإعدادات.
String currencyName(String code) => switch (code.toUpperCase()) {
  'SYP' => 'ليرة سورية',
  'USD' => 'دولار أمريكي',
  'EUR' => 'يورو',
  'TRY' => 'ليرة تركية',
  _ => code,
};

/// صياغة كمية (عبوات/قطع) لا مبلغ: حتى ٣ منازل بلا أصفار لاحقة —
/// «12» و«2.5» لا «12.000». الكميات المجانية قد تأتي كسرية من شريحة بونص.
String formatQuantity(num value) {
  final rounded = (value * 1000).round() / 1000;
  if (rounded == rounded.roundToDouble()) return _group(rounded, 0);
  return _group(rounded, 3).replaceFirst(RegExp(r'0+$'), '');
}

// ─────────────────────────────────────────────────────────────────────

String _group(num value, int decimals) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);

  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final fraction = dot < 0 ? '' : fixed.substring(dot);

  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }

  return '${negative ? '-' : ''}$buf$fraction';
}
