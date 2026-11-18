import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/router/router.dart';
import 'package:tawrid_app/app/theme/app_theme.dart';
import 'package:tawrid_app/app/theme/font_scale_provider.dart';
import 'package:tawrid_app/app/theme/theme_mode_provider.dart';
import 'package:tawrid_app/core/notifications/push_service.dart';

/// مفتاح عالمي لـ ScaffoldMessenger — يُستخدم لإظهار SnackBar فوق BottomSheet.
/// الاستخدام: `appScaffoldMessengerKey.currentState?.showSnackBar(...)`
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TawridApp extends ConsumerStatefulWidget {
  const TawridApp({super.key});

  @override
  ConsumerState<TawridApp> createState() => _TawridAppState();
}

class _TawridAppState extends ConsumerState<TawridApp> {
  @override
  void initState() {
    super.initState();
    // التطبيق أُقلع من نقرة على إشعار: الانتقال يُنفَّذ بعد أول إطار لا
    // في main()، لأن الراوتر لا يقوم إلا مع runApp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushServiceProvider).consumeLaunchNotification();
    });
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale.factor),
        ),
        child: child!,
      ),
    );
  }
}
