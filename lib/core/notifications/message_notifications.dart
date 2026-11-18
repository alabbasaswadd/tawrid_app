import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إشعارات الرسائل في شريط النظام — مُجمَّعة لكل محادثة.
///
/// لماذا يبنيها التطبيق لا النظام: إشعار FCM العادي يعرضه النظام بنفسه
/// سطراً لكل رسالة، فعشر رسائل من مستودع واحد عشرة إشعارات متراصّة. ولا
/// سبيل إلى تجميعها إلا أن تصل الرسالة بيانات خامّة فيبنيها التطبيق.
///
/// الشكل: إشعار واحد لكل محادثة يحمل اسم الطرف الآخر وآخر رسائله بنمط
/// المحادثة (MessagingStyle) — نفس ما تفعله تطبيقات المراسلة. والنقر عليه
/// يفتح محادثته هي، لا شاشة المحادثات.
class MessageNotifications {
  MessageNotifications._();

  /// معرّف القناة يحمل لاحقة النغمة.
  ///
  /// أندرويد يُجمّد إعدادات القناة عند إنشائها — الصوت والأهمية لا
  /// يتغيّران بعدها مهما أعدنا الإنشاء. وتغيير النغمة لاحقاً يستلزم
  /// معرّفاً جديداً، فتُزاد اللاحقة ويُحذف القديم.
  static const _channelId = 'messages_v2';
  static const _channelName = 'الرسائل';
  static const _channelDescription = 'رسائل المحادثات المباشرة';

  /// نغمة الرسائل — ملف في android/app/src/main/res/raw بلا امتداد.
  static const _sound = RawResourceAndroidNotificationSound('message_tone');

  /// قنوات سابقة تُحذف عند الترقية، وإلا بقيت في إعدادات النظام بلا عمل.
  static const _legacyChannelIds = ['messages'];

  /// سجلّ الرسائل الأخيرة لكل محادثة.
  ///
  /// في مساحة تخزين دائمة لا في الذاكرة: معالج الخلفية يعمل في عزلة
  /// (isolate) مستقلّة لا ترى حالة التطبيق، فبلا هذا يبدأ كل إشعار من
  /// رسالة واحدة ويضيع ما قبلها.
  static const _storePrefix = 'msg_notif_';

  /// سقف ما يُعرض في الإشعار الواحد — ما فوقه لا يُقرأ في شريط النظام.
  static const _maxLines = 5;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// يُهيّئ القناة ومعالج النقر. آمن للاستدعاء المتكرّر.
  ///
  /// [onOpenConversation] يُستدعى بمعرّف المحادثة عند النقر على الإشعار.
  static Future<void> init({
    required void Function(String conversationId, String title)
    onOpenConversation,
  }) async {
    if (_ready) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = _decodePayload(response.payload);
        if (payload == null) return;
        onOpenConversation(payload.conversationId, payload.title);
      },
    );

    // القناة تُنشأ صراحةً لتحمل أهمية عالية: المُنشأة ضمناً تأخذ الافتراضي
    // فتصل الرسائل صامتة، ولا يمكن رفع أهمية قناة بعد إنشائها.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            sound: _sound,
          ),
        );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final id in _legacyChannelIds) {
      await android?.deleteNotificationChannel(channelId: id);
    }

    _ready = true;
  }

  /// يُظهر رسالة واردة، مضمومةً إلى سابقاتها في المحادثة نفسها.
  static Future<void> showMessage({
    required String conversationId,
    required String senderName,
    required String body,
  }) async {
    final lines = await _appendLine(conversationId, senderName, body);

    // معرّف ثابت لكل محادثة: الإشعار يُستبدَل ولا يتراكم، فتبقى المحادثة
    // الواحدة إشعاراً واحداً مهما توالت رسائلها.
    final id = conversationId.hashCode & 0x7FFFFFFF;

    final style = MessagingStyleInformation(
      Person(name: senderName),
      conversationTitle: senderName,
      groupConversation: false,
      messages: [
        for (final line in lines)
          Message(line, DateTime.now(), Person(name: senderName)),
      ],
    );

    await _plugin.show(
      id: id,
      title: senderName,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: style,
          // مجموعة لكل محادثة: النظام يضمّ إشعاراتها تحت رأس واحد بدل
          // أن يبعثرها بين إشعارات محادثات أخرى.
          groupKey: 'conversation_$conversationId',
          category: AndroidNotificationCategory.message,
          // يُعاد ذكره هنا أيضاً: القناة تحكم أندرويد ٨ فما فوق، وهذا
          // يحكم ما دونها.
          sound: _sound,
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: conversationId,
          sound: 'message_tone.wav',
        ),
      ),
      payload: jsonEncode({
        'conversationId': conversationId,
        'title': senderName,
      }),
    );
  }

  /// يمحو إشعار محادثة فُتحت — ومعه سجلّ رسائلها.
  ///
  /// بلا المحو يبقى الإشعار في الشريط لرسائل قرأها المستخدم، ويبني عليها
  /// الإشعار التالي فيعرض ما قُرئ مع ما لم يُقرأ.
  static Future<void> clear(String conversationId) async {
    await _plugin.cancel(id: conversationId.hashCode & 0x7FFFFFFF);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storePrefix$conversationId');
  }

  // ── سجلّ الأسطر ──────────────────────────────────────────────────────

  static Future<List<String>> _appendLine(
    String conversationId,
    String senderName,
    String body,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storePrefix$conversationId';

    final lines = [...?prefs.getStringList(key), body];
    final trimmed = lines.length > _maxLines
        ? lines.sublist(lines.length - _maxLines)
        : lines;

    await prefs.setStringList(key, trimmed);
    return trimmed;
  }

  static _NotificationPayload? _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = map['conversationId'] as String?;
      if (id == null || id.isEmpty) return null;
      return _NotificationPayload(id, map['title'] as String? ?? 'محادثة');
    } catch (_) {
      return null;
    }
  }
}

class _NotificationPayload {
  const _NotificationPayload(this.conversationId, this.title);
  final String conversationId;
  final String title;
}
