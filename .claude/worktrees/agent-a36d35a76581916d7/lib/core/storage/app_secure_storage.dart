import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تخزين آمن مُهيّأ لأندرويد:
/// - encryptedSharedPreferences: يستخدم Jetpack EncryptedSharedPreferences (أكثر
///   ثباتاً عبر إصدارات أندرويد من آلية الـ RSA/Keystore الافتراضية).
/// - resetOnError: عند فشل فكّ التشفير (تلف مفتاح Keystore — شائع عند التثبيت فوق
///   نسخة سابقة) يمسح التخزين ويتابع بدل رمي PlatformException وإسقاط تسجيل الدخول.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  ),
);
