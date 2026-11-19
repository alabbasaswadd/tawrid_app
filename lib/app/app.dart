import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/router/router.dart';
import 'package:tawrid_app/app/theme/app_theme.dart';
import 'package:tawrid_app/app/theme/font_scale_provider.dart';
import 'package:tawrid_app/app/theme/theme_mode_provider.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';
import 'package:tawrid_app/shared/widgets/offline_banner.dart';
import 'package:tawrid_app/core/realtime/conversation_hub.dart';

/// مفتاح عالمي لـ ScaffoldMessenger — يُستخدم لإظهار SnackBar فوق BottomSheet.
/// الاستخدام: `appScaffoldMessengerKey.currentState?.showSnackBar(...)`
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TawridApp extends ConsumerStatefulWidget {
  const TawridApp({super.key});

  @override
  ConsumerState<TawridApp> createState() => _TawridAppState();
}

class _TawridAppState extends ConsumerState<TawridApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // التطبيق أُقلع من نقرة على إشعار: الانتقال يُنفَّذ بعد أول إطار لا
    // في main()، لأن الراوتر لا يقوم إلا مع runApp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushServiceProvider).consumeLaunchNotification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// قناة المحادثات تتبع حياة التطبيق — بخروجه لا بتواريه.
  ///
  /// تبقى مفتوحة ما دام التطبيق حيّاً ولو في الخلفية: إغلاقها عند كل
  /// تواري يعني إعادة مصافحة كاملة عند كل عودة، ويُفقد البثَّ الفوري
  /// في النافذة التي يسمح فيها النظام بالعمل خلفياً.
  ///
  /// وتُغلق عند detached وحدها — وهي خروج التطبيق فعلاً. بقاؤها بعده
  /// تسريبٌ لمقبس لا صاحب له.
  ///
  /// وما يقطعه النظام في وضع الخمول تستردّه إعادة الاتصال التلقائية،
  /// ويسدّ ما فات التنبيهُ الفوري ثم إعادة الجلب عند العودة.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hub = ref.read(conversationHubProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // قد يكون النظام قطع المقبس أثناء الخمول — resume لا تفعل شيئاً
        // إن كانت القناة قائمة.
        hub.resume();
      case AppLifecycleState.detached:
        hub.suspend();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // التطبيق حيّ: القناة تبقى.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    return MaterialApp.router(
      title: 'توريد',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(fontScale.factor)),
        // شريط الانقطاع هنا وحده: الموجِّه تحته، فيبقى معروضاً عبر كل
        // انتقال بين الشاشات بلا أن تحمله كل شاشة.
        child: OfflineBanner(child: child!),
      ),
    );
  }
}
