import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.28)!],
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        // الشعار بقياس نسبي لا ثابت: ٢٠٠ بكسل + فاصل + مؤشّر = ٢٨٠،
        // وهو أطول من شاشة قصيرة (نافذة متصفّح صغيرة أو جهاز منخفض)
        // فكان يفيض. السقف ٢٠٠ يبقي المظهر كما هو على الشاشات الطبيعية.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize =
                (constraints.maxHeight * 0.3).clamp(80.0, 200.0).toDouble();
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.jpg',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(
                      height: constraints.maxHeight < 400
                          ? AppSpacing.lg
                          : AppSpacing.xxl),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
