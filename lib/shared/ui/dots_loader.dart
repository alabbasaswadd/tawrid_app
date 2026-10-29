import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// مؤشّر انتظار داخل الأزرار: ثلاث نقاط تنبض بالتتابع.
//
// الدوّارة داخل زرّ صغير تُقرأ كأن الزرّ تعطّل — قطرها يملأ ارتفاعه
// وتُخفي نصّه بالكامل. النقاط أهدأ، وتبقى بعرض ثابت فلا يقفز الزرّ بين
// حالتيه. للشاشات الكاملة استعمل الهياكل (AppListSkeleton) لا هذا.
class DotsLoader extends StatefulWidget {
  const DotsLoader({this.color, this.size = 6, super.key});

  /// لون النقاط — الافتراضي لون نصّ الزرّ الحالي.
  final Color? color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  static const int _count = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? DefaultTextStyle.of(context).style.color ?? context.colors.onPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _count; i++) ...[
          if (i > 0) SizedBox(width: widget.size * 0.7),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, _) {
              // كل نقطة تتأخّر عن سابقتها بثلث الدورة، فتبدو الحركة
              // متتابعة لا متزامنة.
              final t = Interval(
                i * 0.2,
                i * 0.2 + 0.6,
                curve: Curves.easeInOut,
              ).transform(_controller.value);

              // نبضة كاملة ذهاباً وإياباً داخل نافذة كل نقطة.
              final pulse = t < 0.5 ? t * 2 : (1 - t) * 2;

              return Opacity(
                opacity: 0.35 + 0.65 * pulse,
                child: Transform.scale(
                  scale: 0.72 + 0.28 * pulse,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
