import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/storage/app_secure_storage.dart';
import 'package:tawrid_app/models/conversation_models.dart';

final _log = Logger();

final conversationHubProvider = Provider<ConversationHub>((ref) {
  final hub = ConversationHub();
  ref.onDispose(hub.dispose);
  return hub;
});

/// رسالة وصلت فوراً عبر القناة، ومعها المحادثة التي تخصّها.
class IncomingMessage {
  const IncomingMessage({required this.conversationId, required this.message});

  final String conversationId;
  final ConversationMessage message;
}

/// الطرف الآخر فتح المحادثة وقرأ ما أُرسل إليه.
class ConversationReadEvent {
  const ConversationReadEvent({required this.conversationId});

  final String conversationId;
}

/// قناة الأحداث الفورية للمحادثات (SignalR).
///
/// **قناة استقبال فقط.** الإرسال يبقى عبر REST: هناك يمرّ بتحقّق الصلاحية
/// والمُصادِقات والمعاملة، ويعود بتأكيد يُعتمد عليه. هذه القناة تُسرّع
/// الوصول لا أكثر — وإن سقطت، يبقى كل شيء يعمل بالجلب العادي.
///
/// لذلك لا يُبنى عليها شيء لا يمكن استرجاعه بإعادة الجلب: عند
/// [onReconnected] تُعاد قراءة المحادثة من الخادم بدل محاولة تعويض ما فات.
class ConversationHub {
  HubConnection? _connection;
  bool _isWarehouse = false;

  final _messages = StreamController<IncomingMessage>.broadcast();
  final _reads = StreamController<ConversationReadEvent>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// رسائل واردة لأي محادثة — المستمع يُصفّي ما يعنيه.
  Stream<IncomingMessage> get messages => _messages.stream;

  /// إشعارات القراءة من الطرف الآخر.
  Stream<ConversationReadEvent> get reads => _reads.stream;

  /// نبضة بعد كل عودة اتصال — إشارة لإعادة الجلب وسدّ ما فات أثناء الانقطاع.
  Stream<void> get onReconnected => _reconnected.stream;

  /// خادمٌ أقدم من إضافة الإرسال عبر القناة — يُكتشف من أول محاولة
  /// ويُحفَظ، فلا تُجرَّب طريقةٌ معدومة مع كل رسالة.
  bool _sendUnsupported = false;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  /// هل يصلح الإرسال عبر القناة الآن؟ متصلة، والخادم يعرف الطريقة.
  bool get canSend => isConnected && !_sendUnsupported;

  /// يُرسل رسالة عبر الاتصال القائم ويُعيدها مؤكَّدةً من الخادم.
  ///
  /// رسالةٌ على قناة مفتوحة بدل طلب HTTP جديد لكل سطر: لا مصافحة ولا
  /// ترويسات ولا تحليل توكن من جديد في كل مرة.
  ///
  /// يرمي إن كانت القناة مغلقة — ليسقط المُستدعي إلى REST بدل أن تضيع
  /// الرسالة بصمت. الصلاحية والمُصادِقات تجري في الخادم كما في REST
  /// تماماً: الـ Hub يُفوّض إلى الأمر نفسه.
  Future<ConversationMessage> sendMessage(
    String conversationId,
    String content,
  ) async {
    final connection = _connection;
    if (connection == null ||
        connection.state != HubConnectionState.Connected) {
      throw StateError('القناة غير متصلة');
    }

    final Object? raw;
    try {
      raw = await connection.invoke(
        'SendMessage',
        args: [conversationId, content],
      );
    } catch (e) {
      // خادم لا يعرف الطريقة أصلاً: لم يُكتب شيء، والمحاولة لن تنجح
      // في المرّات التالية — نُطفئ المسار ونترك المُستدعي يسقط إلى REST.
      if (_looksLikeMissingMethod(e)) {
        _sendUnsupported = true;
        _log.w('[Hub] الخادم لا يدعم الإرسال عبر القناة — الاعتماد على REST.');
      }
      rethrow;
    }

    if (raw is! Map) throw StateError('ردٌّ غير مفهوم من الخادم');
    return ConversationMessage.fromJson(Map<String, dynamic>.from(raw));
  }

  // رسالة SignalR حين تُستدعى طريقة لا وجود لها على الخادم. تمييزها
  // يهمّ: هذه وحدها تضمن أن شيئاً لم يُكتب، فالسقوط إلى REST بعدها
  // لا يُكرّر رسالة.
  static bool _looksLikeMissingMethod(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('does not exist') || text.contains('method');
  }

  /// يُعلّم المحادثة مقروءة عبر القناة — بلا ردّ ينتظره أحد.
  Future<void> markRead(String conversationId) async {
    final connection = _connection;
    if (connection == null ||
        connection.state != HubConnectionState.Connected) {
      throw StateError('القناة غير متصلة');
    }
    await connection.send('MarkRead', args: [conversationId]);
  }

  /// يفتح القناة لجلسة قائمة. آمن للاستدعاء المتكرّر.
  Future<void> connect({required bool isWarehouse}) async {
    // تبديل الجهة على الجهاز نفسه يستوجب قناة جديدة: المجموعة تُشتقّ من
    // التوكن عند الاتصال، فقناة الصيدلية لا تصلح للمستودع.
    if (_connection != null && _isWarehouse == isWarehouse) return;
    await disconnect();

    final token = await appSecureStorage.read(
      key: isWarehouse ? StorageKeys.warehouseToken : StorageKeys.pharmacyToken,
    );
    if (token == null || token.isEmpty) {
      _log.w('[Hub] لا توكن لهذه الجهة — القناة لم تُفتح.');
      return;
    }

    _isWarehouse = isWarehouse;
    // اتصالٌ جديد قد يكون إلى خادم مُحدَّث — تُعاد المحاولة مرّة.
    _sendUnsupported = false;

    final connection = HubConnectionBuilder()
        .withUrl(
          '$apiBaseUrl${ApiEndpoints.conversationsHub}',
          options: HttpConnectionOptions(
            // تُقرأ عند كل محاولة اتصال لا مرة واحدة: الرمز قد يتغيّر بين
            // انقطاع وعودة، وقراءته هنا تجعل إعادة الاتصال تحمل الحالي.
            accessTokenFactory: () async =>
                await appSecureStorage.read(
                  key: isWarehouse
                      ? StorageKeys.warehouseToken
                      : StorageKeys.pharmacyToken,
                ) ??
                '',
          ),
        )
        // تصاعديّ: محاولة فورية ثم تباعد، فلا نُغرق خادماً متعثّراً
        // بمحاولات كل ثانية من كل جهاز.
        .withAutomaticReconnect(
          retryDelays: [0, 2000, 5000, 10000, 20000, 30000],
        )
        .build();

    connection.on('messageReceived', _onMessageReceived);
    connection.on('conversationRead', _onConversationRead);

    connection.onreconnected(({connectionId}) {
      _log.i('[Hub] عاد الاتصال.');
      if (!_reconnected.isClosed) _reconnected.add(null);
    });

    connection.onclose(({error}) {
      if (error != null) _log.w('[Hub] أُغلقت القناة: $error');
    });

    _connection = connection;

    try {
      await connection.start();
      _log.i('[Hub] القناة مفتوحة (${isWarehouse ? 'مستودع' : 'صيدلية'}).');
    } catch (e) {
      // فشل الفتح ليس خطأً قاتلاً: الشاشات تعمل بالجلب العادي.
      _log.w('[Hub] تعذّر فتح القناة — المتابعة بلا بثّ فوري: $e');
      _connection = null;
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (e) {
      _log.w('[Hub] تعذّر إغلاق القناة: $e');
    }
  }

  void _onMessageReceived(List<Object?>? args) {
    final payload = _firstMap(args);
    if (payload == null) return;

    final raw = payload['message'];
    final conversationId = payload['conversationId'] as String?;
    if (conversationId == null || raw is! Map) return;

    try {
      _messages.add(
        IncomingMessage(
          conversationId: conversationId,
          message: ConversationMessage.fromJson(Map<String, dynamic>.from(raw)),
        ),
      );
    } catch (e) {
      // حمولة لا تطابق المتوقَّع (عقد تغيّر؟) تُسجَّل ولا تُسقط القناة.
      _log.w('[Hub] حمولة رسالة غير مفهومة: $e');
    }
  }

  void _onConversationRead(List<Object?>? args) {
    final payload = _firstMap(args);
    final conversationId = payload?['conversationId'] as String?;
    if (conversationId == null) return;
    _reads.add(ConversationReadEvent(conversationId: conversationId));
  }

  static Map<String, dynamic>? _firstMap(List<Object?>? args) {
    final first = (args == null || args.isEmpty) ? null : args.first;
    return first is Map ? Map<String, dynamic>.from(first) : null;
  }

  void dispose() {
    unawaited(disconnect());
    _messages.close();
    _reads.close();
    _reconnected.close();
  }
}
