import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:tawrid_app/core/constants/storage_keys.dart';
import 'package:tawrid_app/core/storage/app_secure_storage.dart';
import 'package:tawrid_app/repositories/device_repository.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';

final _log = Logger();

/// إعدادات Firebase للعميل تُمرَّر وقت البناء، لا تُخزَّن في المستودع.
///
/// على أندرويد يقرأها الإضافة من `google-services.json` تلقائياً فلا حاجة
/// إليها هنا؛ أما الويب فيحتاجها صراحةً:
///   flutter run -d chrome \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=... \
///     --dart-define=FIREBASE_SENDER_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=tawrid-6adcd
///
/// هذه القيم ليست أسراراً (تُشحن داخل أي تطبيق عميل)، لكنها تُترك خارج
/// الشيفرة ليبقى الملف صالحاً لأي مشروع Firebase.
class _WebFirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'tawrid-6adcd');

  static bool get isComplete =>
      apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      );
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// الإشعارات الفورية عبر Firebase Cloud Messaging.
///
/// مبدأ التصميم: **التنبيه الفوري إضافة لا شرط**. إن غابت إعدادات Firebase
/// أو رفض المستخدم الإذن، يبقى صندوق الإشعارات وكل التطبيق يعمل — تماماً
/// كما يفعل الخادم حين يكون `Firebase:Enabled=false`. لذلك كل خطوة هنا
/// محروسة وتُسجَّل بتحذير بدل أن تُسقط الإقلاع.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  bool _ready = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  bool get isReady => _ready;
  String? get token => _token;

  /// تهيئة Firebase مرة واحدة عند إقلاع التطبيق.
  Future<void> init() async {
    if (_ready) return;
    try {
      if (kIsWeb) {
        if (!_WebFirebaseConfig.isComplete) {
          _log.w('[Push] إعدادات Firebase للويب غير مُمرَّرة — التنبيه الفوري معطَّل.');
          return;
        }
        await Firebase.initializeApp(options: _WebFirebaseConfig.options);
      } else {
        // أندرويد/iOS يقرآن الإعدادات من ملفّي المنصّة.
        await Firebase.initializeApp();
      }
      _ready = true;
      _listenForTokenRefresh();
      _listenForForegroundMessages();
    } catch (e) {
      // غياب google-services.json أو إعدادات الويب يرمي هنا — وهو وضع
      // متوقَّع قبل ضبط المشروع، لا خطأ يستحق إسقاط التطبيق.
      _log.w('[Push] تعذّرت تهيئة Firebase — التنبيه الفوري معطَّل: $e');
      _ready = false;
    }
  }

  /// طلب الإذن وجلب الرمز وتسجيله لدى الجهة الحالية.
  ///
  /// يُستدعى بعد تسجيل الدخول: قبله لا نعرف لمن نُسجّل الجهاز.
  Future<void> registerForSession({required bool isWarehouse}) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log.i('[Push] رفض المستخدم إذن الإشعارات — الصندوق وحده يعمل.');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _log.w('[Push] لا رمز FCM متاح.');
        return;
      }

      await _sendToken(token, isWarehouse: isWarehouse);
    } catch (e) {
      _log.w('[Push] تعذّر تسجيل الجهاز: $e');
    }
  }

  /// إلغاء تسجيل الجهاز عند الخروج — وإلا بقيت إشعارات الحساب السابق
  /// تصل إلى الجهاز بعد خروجه منه.
  Future<void> unregisterForSession({required bool isWarehouse}) async {
    const store = appSecureStorage;
    final saved = _token ?? await store.read(key: StorageKeys.fcmToken);
    if (saved == null || saved.isEmpty) return;

    try {
      await _ref
          .read(deviceRepositoryProvider)
          .unregister(isWarehouse: isWarehouse, token: saved);
    } catch (e) {
      // فشل الإلغاء لا يمنع الخروج: الخادم ينظّف الرموز الميتة عند أول
      // إرسال فاشل، والجلسة المحلية تُمحى على كل حال.
      _log.w('[Push] تعذّر إلغاء تسجيل الجهاز: $e');
    } finally {
      await store.delete(key: StorageKeys.fcmToken);
      await store.delete(key: StorageKeys.fcmTokenOwner);
      _token = null;
    }
  }

  Future<void> _sendToken(String token, {required bool isWarehouse}) async {
    const store = appSecureStorage;
    final owner = isWarehouse ? 'warehouse' : 'pharmacy';
    final lastToken = await store.read(key: StorageKeys.fcmToken);
    final lastOwner = await store.read(key: StorageKeys.fcmTokenOwner);

    // لا نُعيد إرسال رمز لم يتغيّر لنفس الجهة — إقلاعٌ عادي لا يستحق
    // رحلة شبكة. يتغيّر أحدهما ⇒ نُسجّل من جديد.
    if (token == lastToken && owner == lastOwner) {
      _token = token;
      return;
    }

    await _ref.read(deviceRepositoryProvider).register(
          isWarehouse: isWarehouse,
          token: token,
          platform: _platform,
          deviceId: await _deviceId(),
        );

    _token = token;
    await store.write(key: StorageKeys.fcmToken, value: token);
    await store.write(key: StorageKeys.fcmTokenOwner, value: owner);
    _log.i('[Push] سُجّل الجهاز لجهة $owner.');
  }

  // الرمز يتغيّر من تلقاء نفسه (إعادة تثبيت، مسح بيانات، دورة أمان)،
  // وبلا إعادة تسجيل تتوقّف الإشعارات صامتةً.
  void _listenForTokenRefresh() {
    _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      const store = appSecureStorage;
      final owner = await store.read(key: StorageKeys.fcmTokenOwner);
      if (owner == null) return; // لا جلسة قائمة — يُسجَّل عند الدخول.
      await _sendToken(token, isWarehouse: owner == 'warehouse');
    });
  }

  // إشعار يصل والتطبيق مفتوح لا يُظهره النظام، فنُحدّث شارة الجرس على
  // الأقل بدل أن يبدو الصندوق قديماً.
  void _listenForForegroundMessages() {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((_) async {
      final owner =
          await appSecureStorage.read(key: StorageKeys.fcmTokenOwner);
      if (owner == null) return;
      _ref.invalidate(
          owner == 'warehouse' ? whUnreadCountProvider : phUnreadCountProvider);
    });
  }

  DevicePlatform get _platform {
    if (kIsWeb) return DevicePlatform.web;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? DevicePlatform.ios
        : DevicePlatform.android;
  }

  /// معرّف ثابت للجهاز عبر عمليات الإقلاع — الخادم يستخدمه للتمييز بين
  /// أجهزة الحساب الواحد. نُولّده مرة ونحفظه بدل حزمة إضافية لقراءة
  /// معرّف العتاد (وهو محجوب على الويب أصلاً).
  Future<String> _deviceId() async {
    const store = appSecureStorage;
    final existing = await store.read(key: StorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated =
        '${kIsWeb ? 'web' : defaultTargetPlatform.name}-'
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await store.write(key: StorageKeys.deviceId, value: generated);
    return generated;
  }

  void dispose() {
    _refreshSub?.cancel();
    _foregroundSub?.cancel();
  }
}
