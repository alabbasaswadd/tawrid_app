import 'package:url_launcher/url_launcher.dart';

/// رمز الاتصال الدولي لسوريا — سوق المنصّة.
///
/// الأرقام تُدخَل محلياً («0912345678») بينما واتساب يطلبها دوليةً بلا صفر
/// ولا «+». التحويل هنا في موضع واحد لا في كل زرّ.
const String kCountryDialCode = '963';

/// رقم الهاتف بصيغة واتساب الدولية، أو null إن لم يكن رقماً صالحاً.
///
/// يقبل ما يُدخله الناس فعلاً: «0912 345 678»، «+963912345678»،
/// «00963912345678»، «963912345678». وما لا يحتوي أرقاماً كافيةً يُرفض
/// بدل أن يفتح واتساب على رقم مشوَّه.
String? whatsAppNumber(String? raw) {
  if (raw == null) return null;

  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('00')) digits = digits.substring(2);

  if (digits.startsWith(kCountryDialCode)) {
    // رقم دولي أصلاً.
  } else if (digits.startsWith('0')) {
    digits = '$kCountryDialCode${digits.substring(1)}';
  } else if (digits.length <= 10) {
    // رقم محلي بلا صفر بادئ.
    digits = '$kCountryDialCode$digits';
  }

  // أقصر رقم دولي معقول ١١ خانة (٩٦٣ + تسع خانات).
  return digits.length >= 11 && digits.length <= 15 ? digits : null;
}

/// فتح محادثة واتساب مع الرقم، مع رسالة مبدئية اختيارية.
///
/// يُرجع false إن تعذّر الفتح (لا واتساب على الجهاز، أو رقم غير صالح)
/// فيستطيع موضع الاستدعاء إخبار المستخدم بدل الصمت.
Future<bool> openWhatsApp(String? rawPhone, {String? message}) async {
  final number = whatsAppNumber(rawPhone);
  if (number == null) return false;

  // wa.me يعمل على الويب وعلى الجوّال ويفتح التطبيق إن كان مثبَّتاً،
  // فلا حاجة إلى مخطَّط whatsapp:// الخاص بكل منصّة.
  final uri = Uri.https('wa.me', '/$number', {
    if (message != null && message.isNotEmpty) 'text': message,
  });

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
