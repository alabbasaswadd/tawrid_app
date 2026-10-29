import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _loaderFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              // المحتوى الرئيسي — Alignment.center لا يتأثر بـ RTL
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // اللوغو + حلقة التوهّج
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            width: 108,
                            height: 108,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x2l),

                    // الاسم والوصف
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'توريد',
                            textAlign: TextAlign.center,
                            style: context.text.displayLarge?.copyWith(
                              color: cs.onPrimary,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'المنصة الذكية للتوريد الدوائي',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // مؤشر التحميل في الأسفل
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3l),
                  child: FadeTransition(
                    opacity: _loaderFade,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: cs.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
