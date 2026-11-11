import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/tokens.dart';

// يوسّط المحتوى ضمن عرض أقصى على الشاشات العريضة (بدل تمدّد قبيح).
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

extension ResponsiveX on BuildContext {
  bool get isTablet => MediaQuery.sizeOf(this).width >= AppBreakpoints.tablet;
}
