import 'package:flutter/foundation.dart';

/// هل يصل التطبيق إلى الخادم الآن؟
///
/// مقيسٌ من نتائج الطلبات الفعلية لا من حالة الواجهة اللاسلكية: الهاتف
/// قد يكون موصولاً بشبكةٍ لا تُوصِّل (بوّابة فندق، بياناتٌ نفدت، خادمٌ
/// ساقط)، فسؤال «هل الواي‑فاي مفتوح؟» يُجيب نعم والتطبيق أعمى. وما
/// يَهُمّ المستخدم أن يعرفه هو الوصول، وهذا ما يُقاس هنا.
///
/// والبثّ عبر [ValueNotifier] لا Riverpod: يكتب فيه اعتراضُ dio الذي
/// يعمل خارج شجرة المزوّدات، وقراءته في الواجهة تبقى ببناءٍ واحد عبر
/// [ValueListenableBuilder].
class ServerReachability {
  ServerReachability._();

  /// `true` حين ينقطع الوصول — وتبقى كذلك حتى ينجح طلبٌ واحد.
  static final ValueNotifier<bool> unreachable = ValueNotifier(false);

  /// فشلٌ في الطريق: لا اتصال أو مهلة انتهت.
  static void reportUnreachable() => unreachable.value = true;

  /// وصل ردٌّ من الخادم — أيّاً كان رمزه. حتى الأربعمئة دليلُ وصول،
  /// فالطريق سالك والخلاف على محتوى الطلب لا على بلوغه.
  static void reportReachable() {
    if (unreachable.value) unreachable.value = false;
  }
}
