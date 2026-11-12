import 'package:flutter_test/flutter_test.dart';
import 'package:tawrid_app/models/bonus_tier.dart';
import 'package:tawrid_app/shared/utils/bonus_tiers.dart';
import 'package:tawrid_app/shared/utils/money.dart';

void main() {
  group('صياغة المبالغ تتبع العملة', () {
    test('الدولار بمنزلتين — أسعار نشرة مستودع الحياة', () {
      expect(formatMoneyWith(2.25, 'USD'), '2.25 \$');
      expect(formatMoneyWith(0.87, 'USD'), '0.87 \$');
      expect(formatMoneyWith(0.35, 'USD'), '0.35 \$');
      expect(formatMoneyWith(19.88, 'USD'), '19.88 \$');
    });

    test('الليرة صحيحة بفاصل آلاف', () {
      expect(formatMoneyWith(530000, 'SYP'), '530,000 ل.س');
      expect(formatMoneyWith(12500, 'SYP'), '12,500 ل.س');
    });

    test('الكميات بلا أصفار لاحقة', () {
      expect(formatQuantity(12), '12');
      expect(formatQuantity(2.5), '2.5');
      expect(formatQuantity(0), '0');
    });
  });

  group('شرائح البونص', () {
    BonusTier t(double buy, double free) =>
        BonusTier(buyQuantity: buy, freeQuantity: free, label: '');

    test('سلّم ساكوفال 49/51 — الشرائح تُركَّب', () {
      final tiers = [t(10, 5), t(5, 2), t(3, 1)];
      expect(freeQuantityFor(tiers, 25), 12); // 2×(10+5) + 1×(5+2)
      expect(freeQuantityFor(tiers, 10), 5);
      expect(freeQuantityFor(tiers, 9), 3);
      expect(freeQuantityFor(tiers, 2), 0);
      expect(freeQuantityFor(tiers, 100), 50);
    });

    test('سلّم شاذّ: المضبوط يتفوّق على الجشع', () {
      final tiers = [t(7, 4), t(10, 5)];
      expect(freeQuantityFor(tiers, 10), 5); // الجشع كان يعطي 4
    });

    test('بلا شرائح أو بكمية صفر', () {
      expect(freeQuantityFor(const [], 50), 0);
      expect(freeQuantityFor([t(10, 2)], 0), 0);
      expect(freeQuantityFor([t(10, 2)], 9), 0);
      expect(freeQuantityFor([t(10, 2)], 25), 4);
    });
  });

  group('حوار الكمية — الخطوة والعتبة', () {
    BonusTier t(double buy, double free) =>
        BonusTier(buyQuantity: buy, freeQuantity: free, label: '$buy + $free');

    // الخطوة من الإنتاج نفسه: يستخدمها حوار الإضافة ومِعداد السلّة
    // معاً، فنسختُها هنا كانت تختبر نفسها لا الشاشتين.
    const stepOf = quantityStepFor;

    test('(10+2): تبدأ من 10 وتقفز إلى 20 والبونص يتبعها', () {
      final tiers = [t(10, 2)];
      final step = stepOf(tiers);
      expect(step, 10);
      expect(freeQuantityFor(tiers, step.toDouble()), 2);
      expect(freeQuantityFor(tiers, (step * 2).toDouble()), 4);
      expect(freeQuantityFor(tiers, (step * 3).toDouble()), 6);
    });

    test('سلّم متعدّد: الخطوة أصغر عتبة', () {
      final tiers = [t(10, 5), t(5, 2), t(3, 1)];
      expect(stepOf(tiers), 3);
      expect(freeQuantityFor(tiers, 3), 1);
      expect(freeQuantityFor(tiers, 25), 12);
    });

    test('بلا شرائح: الخطوة واحد ولا بونص', () {
      expect(stepOf(const []), 1);
      expect(freeQuantityFor(const [], 10), 0);
    });

    test('شريحة بكمية غير موجبة لا تصير خطوة', () {
      // سلّمٌ فيه شريحة تالفة كان سيجعل الخطوة صفراً فيتجمّد المِعداد.
      expect(stepOf([t(0, 5), t(10, 2)]), 10);
      expect(stepOf([t(0, 5)]), 1);
    });
  });
}
