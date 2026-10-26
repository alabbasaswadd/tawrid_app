import 'package:flutter/material.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

/// كم بقي على انتهاء العرض بصياغة الواجهة.
///
/// الصياغة تتدرّج مع قرب الموعد لأن «ينتهي ٢٠٢٦/١١/٠٢» لا يعني شيئاً
/// لصيدلي يقرأ القائمة بسرعة، بينما «ينتهي خلال ٣ أيام» يعني قراراً.
String offerExpiryText(DateTime expiresAt) {
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days < 0) return 'انتهى';
  if (days == 0) return 'ينتهي اليوم';
  if (days == 1) return 'ينتهي غداً';
  if (days <= 7) return 'ينتهي خلال $days أيام';
  return 'ينتهي في ${expiresAt.year}/${expiresAt.month}/${expiresAt.day}';
}

/// عرضٌ يُعدّ «قريب الانتهاء» خلال ثلاثة أيام — العتبة نفسها التي تُلوّن
/// سطر المهلة وتضع شارة «ينتهي قريباً» في التصميم.
bool isOfferExpiringSoon(DateTime expiresAt) {
  final days = expiresAt.difference(DateTime.now()).inDays;
  return days >= 0 && days <= 3;
}

/// بطاقة العرض كما في Figma، مبنيّة على مكوّن [OfferCard] من مكتبة التصميم.
///
/// تجمع هذه الطبقة الرقيقة قواعد العرض في موضع واحد بدل تكرارها في
/// الرئيسية وشاشة العروض: معاينة الأصناف، سطر التغطية، نصّ المهلة،
/// وأي الشارات تظهر. المكوّن نفسه لا يعرف شيئاً عن نموذج البيانات.
class OfferSummaryCard extends StatelessWidget {
  const OfferSummaryCard({
    required this.offer,
    this.onAdd,
    this.onDetails,
    super.key,
  });

  final SalesOfferSummary offer;
  final VoidCallback? onAdd;
  final VoidCallback? onDetails;

  // «أموكسيسيلين 500 · سيفترياكسون 1غ · +3 أصناف» — اسمان ثم البقية عدداً،
  // فالسطر يبقى سطراً واحداً مهما كبر العرض.
  String get _itemsPreview {
    final names = offer.itemNames;
    if (names.isEmpty) return '${offer.itemCount} صنف';
    final shown = names.take(2).toList();
    final rest = offer.itemCount - shown.length;
    return [
      ...shown,
      if (rest > 0) '+$rest ${rest == 1 ? 'صنف' : 'أصناف'}',
    ].join(' · ');
  }

  // «يغطي: دمشق · ريف دمشق · إدلب» — المناطق المستهدَفة بالعرض.
  String get _coverage {
    if (offer.targetRegions.isEmpty) return 'يغطي كل المناطق التي يخدمها المستودع';
    final labels = offer.targetRegions.map((r) => r.label).toList();
    final shown = labels.take(3).join(' · ');
    final rest = labels.length - 3;
    return rest > 0 ? 'يغطي: $shown +$rest' : 'يغطي: $shown';
  }

  OfferCardStatus get _status {
    // البونص يسبق قرب الانتهاء في الأولوية: هو سبب الشراء، والمهلة ظرفه.
    if (offer.hasAnyBonus) return OfferCardStatus.bonus;
    if (isOfferExpiringSoon(offer.expiresAt)) return OfferCardStatus.expiring;
    return OfferCardStatus.normal;
  }

  String? get _statusLabel => switch (_status) {
        OfferCardStatus.bonus => offer.hasOfferBonus
            ? 'بونص على العرض'
            : 'بونص على الأصناف',
        OfferCardStatus.expiring => 'ينتهي قريباً',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return OfferCard(
      title: offer.title,
      itemsPreview: _itemsPreview,
      warehouse: offer.warehouseName,
      expiryText: offerExpiryText(offer.expiresAt),
      minOrderText: _coverage,
      // التذييل يعرض عدد الأصناف لا سعراً: الملخّص لا يحمل إجمالياً،
      // والعدد هو ما يميّز عرضاً متعدّد الأصناف في القائمة.
      totalLabel: 'عدد الأصناف',
      totalPrice: '${offer.itemCount} ${offer.itemCount == 1 ? 'صنف' : 'أصناف'}',
      status: _status,
      statusLabel: _statusLabel,
      onAdd: onAdd,
      onDetails: onDetails,
    );
  }
}
