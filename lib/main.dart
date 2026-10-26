import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/app.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';
import 'package:tawrid_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // حاوية واحدة للتهيئة والتطبيق معاً: لو مرّرنا ProviderScope بلا حاوية
  // لصار لدينا نسختان من كل مزوّد — تُسجَّل الأجهزة في واحدة وتقرأ
  // الشاشات من الأخرى.
  final container = ProviderContainer();

  // تهيئة الإشعارات قبل الإقلاع. الدالة محروسة بالكامل: غياب إعدادات
  // Firebase يُعطّل التنبيه الفوري ولا يمنع التطبيق من العمل.
  await container.read(pushServiceProvider).init();

  runApp(
    UncontrolledProviderScope(container: container, child: const TawridApp()),
  );
}
