import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/models/notification_models.dart';

/// وجهة الإشعار: الكيان نفسه لا قائمته.
///
/// مصدر واحد يقرؤه الطرفان — صندوق الإشعارات داخل التطبيق، وإشعار النظام
/// حين يُنقَر من خارجه. لو تكرّر المنطق في الموضعين لانحرف أحدهما عن
/// الآخر بصمت، فيفتح المسار نفسه شاشتين مختلفتين حسب مكان الضغط.
///
/// يُرجع `null` لما لا وجهة له — عندها يُفتح التطبيق على حاله بلا قفزة.
String? notificationDestination({
  required NotificationType type,
  required String? referenceId,
  required bool isWarehouse,
  String? title,
}) {
  final id = referenceId;
  if (id == null || id.isEmpty) return null;

  final wh = isWarehouse;

  return switch (type) {
    // طلبية: أُنشئت أو تغيّرت حالتها (تأكيد/رفض/تجهيز/شحن/تسليم).
    // referenceId هو معرّف الطلبية، فتُفتح تفاصيلها مباشرة.
    NotificationType.supplyOrderStatusChanged ||
    NotificationType.supplyOrderCreated ||
    NotificationType.newSupplyOrder ||
    NotificationType.newOrderMessage =>
      wh ? TRoutes.whOrderDetail(id) : TRoutes.phOrderDetail(id),

    // رسالة مباشرة — referenceId معرّف المحادثة، والعنوان اسم المُرسِل
    // فيُستعمل عنواناً للشاشة بلا رحلة شبكة إضافية.
    NotificationType.newDirectMessage =>
      wh
          ? TRoutes.whConversationDetail(id, title ?? '')
          : TRoutes.phConversationDetail(id, title ?? ''),

    // طلب تسعير: الصيدلية تقارن العروض على طلبها، والمستودع يقدّم عرضه.
    NotificationType.quotationRequestAwarded ||
    NotificationType.newQuotationRequest =>
      wh ? TRoutes.whSubmitTenderOffer(id) : TRoutes.phCompareQuotations(id),
    NotificationType.newQuotation =>
      wh ? null : TRoutes.phCompareQuotations(id),

    // عرض بيع أو تعليق عليه — referenceId معرّف العرض في الحالتين.
    NotificationType.newSalesOffer || NotificationType.newComment =>
      wh ? TRoutes.whOfferDetail(id) : TRoutes.phOfferDetail(id),

    // إعلان مستودع: لا شاشة تفاصيل له بعد، فالقائمة أقرب ما يفيد.
    NotificationType.warehouseAnnouncement =>
      wh ? TRoutes.whOffers : TRoutes.phOffers,

    NotificationType.general || NotificationType.unknown => null,
  };
}

/// وجهة إشعار فوري قادم من FCM.
///
/// الخادم يضع في `data` مفتاحَي `type` (رقم) و`referenceId` — وهما ما
/// يحتاجه التوجيه. النوع المجهول يُقرأ `unknown` فلا يقفز بالمستخدم إلى
/// شاشة خاطئة، ولا يُسقط شيئاً.
///
/// [title] يأتي من كتلة `notification` في رسالة FCM لا من `data` — وهو
/// اسم المُرسِل في إشعار الرسالة، يُستعمل عنواناً لشاشة المحادثة.
String? pushDestination(
  Map<String, dynamic> data, {
  required bool isWarehouse,
  String? title,
}) {
  final code = int.tryParse('${data['type']}');
  if (code == null) return null;

  return notificationDestination(
    type: NotificationType.fromCode(code),
    referenceId: data['referenceId'] as String?,
    isWarehouse: isWarehouse,
    title: title,
  );
}
