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
}
