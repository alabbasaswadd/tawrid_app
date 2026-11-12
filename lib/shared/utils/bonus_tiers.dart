/// حساب الكمية المجانية من شرائح البونص — «اشترِ N واحصل على M مجاناً».
///
/// **نسخة مطابقة لـ `BonusTierCalculator` في الخادم** (Tawrid.Domain/Pricing).
/// الخادم هو مصدر الحقيقة: كل استجابة تحمل `freeQuantity` محسوبة منه، وهذه
/// النسخة للمعاينة الفورية وحدها (تغيير الكمية قبل وصول الرد). وجودُها ليس
/// ترفاً: بدونها يبقى الرقم القديم معروضاً لحظةً فيقرأ الصيدلي مجانيّةَ
/// كميةٍ لم يعد يطلبها. وأي تعديل على خوارزمية الخادم يلزمه تعديلٌ هنا.
///
/// الشرائح **تُركَّب**: الكمية 25 أمام (10+5) و(5+2) تستهلك
/// 2×(10+5) + 1×(5+2) = 12 مجاناً، لا 10 فقط.
library;

import 'package:tawrid_app/models/cart_models.dart';

const int _maxTiers = 10;
const double _exactSolverLimit = 100000;

/// الكمية المجانية المستحقّة على [quantity]. بلا شرائح ⇒ صفر.
double freeQuantityFor(List<BonusTier> tiers, double quantity) {
  final usable = _sanitize(tiers);
  if (usable.isEmpty || quantity <= 0) return 0;

  return _canSolveExactly(usable, quantity)
      ? _exact(usable, quantity)
      : _greedy(usable, quantity);
}

// شريحة بكمية غير موجبة ليست شريحة. والتكرار على نفس كمية الشراء يُحسَم
// بالأعلى بونصاً — نفس ترتيب الخادم: الأعلى عائداً أولاً.
List<BonusTier> _sanitize(List<BonusTier> tiers) {
  final byBuy = <double, BonusTier>{};
  for (final t in tiers) {
    if (t.buyQuantity <= 0 || t.freeQuantity <= 0) continue;
    final existing = byBuy[t.buyQuantity];
    if (existing == null || t.freeQuantity > existing.freeQuantity) {
      byBuy[t.buyQuantity] = t;
    }
  }

  final list = byBuy.values.toList()
    ..sort((a, b) {
      final byRate = (b.freeQuantity / b.buyQuantity).compareTo(
        a.freeQuantity / a.buyQuantity,
      );
      return byRate != 0 ? byRate : b.buyQuantity.compareTo(a.buyQuantity);
    });

  return list.length > _maxTiers ? list.sublist(0, _maxTiers) : list;
}

bool _canSolveExactly(List<BonusTier> tiers, double quantity) =>
    quantity <= _exactSolverLimit &&
    _isWhole(quantity) &&
    tiers.every((t) => _isWhole(t.buyQuantity));

bool _isWhole(double value) => value == value.roundToDouble();

// برمجة ديناميكية (حقيبة غير محدودة) — النتيجة هي المثلى قطعاً. الجشع
// يخطئ على سلالم شاذّة: (7+4) و(10+5) عند الكمية 10 يعطي 4 لا 5.
double _exact(List<BonusTier> tiers, double quantity) {
  final n = quantity.round();
  final best = List<double>.filled(n + 1, 0);

  for (var q = 1; q <= n; q++) {
    best[q] = best[q - 1]; // ترك وحدة بلا شريحة خيارٌ دائماً
    for (final tier in tiers) {
      final buy = tier.buyQuantity.round();
      if (buy > q) continue;
      final candidate = best[q - buy] + tier.freeQuantity;
      if (candidate > best[q]) best[q] = candidate;
    }
  }

  return best[n];
}

double _greedy(List<BonusTier> tiers, double quantity) {
  var free = 0.0;
  var remaining = quantity;

  for (final tier in tiers) {
    if (remaining <= 0) break;
    final times = (remaining / tier.buyQuantity).floor();
    if (times <= 0) continue;
    free += times * tier.freeQuantity;
    remaining -= times * tier.buyQuantity;
  }

  return free;
}

/// خطوة الزيادة والنقصان المناسبة لسلّم بونص — أصغر كمية شراء فيه، أو ‎1‎
/// بلا سلّم.
///
/// مشتركة بين حوار «تحديد الكمية» ومِعداد السلّة: كلاهما يزيد الكمية على
/// صنفٍ واحد، فاختلافُ خطوتهما يُقرأ عطلاً — يختار الصيدلي ‎10‎ في الحوار
/// ثمّ يضغط ‎+‎ في السلّة فتصير ‎11‎، فيخسر البونص بزيادةٍ ظنّها ربحاً.
int quantityStepFor(List<BonusTier> tiers) {
  var step = 0;
  for (final t in tiers) {
    final buy = t.buyQuantity.round();
    if (buy <= 0) continue;
    if (step == 0 || buy < step) step = buy;
  }
  return step == 0 ? 1 : step;
}
