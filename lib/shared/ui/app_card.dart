import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// بطاقة موحّدة — سطح + حدّ 1px + زاوية ثابتة. تقرأ من الثيم (تتكيّف مع الدارك).
class AppCard extends StatelessWidget {
  const AppCard({
    this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 14,
    ),
    this.onTap,
    this.color,
    this.bordered = true,
    this.radius = AppSpacing.cardRadius,
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool bordered;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final decoration = BoxDecoration(
      color: color ?? cs.surface,
      borderRadius: BorderRadius.circular(radius),
      border: bordered ? Border.all(color: cs.outline) : null,
      boxShadow: context.tokens.cardShadow,
    );
    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(decoration: decoration, child: content),
      ),
    );
  }
}
