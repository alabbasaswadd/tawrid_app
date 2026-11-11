import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// شريحة تصفية سريعة (Figma: شريحة فلتر): غير محددة بسطح أبيض وحد رمادي،
// محددة بتعبئة خضراء، وقابلة للإزالة عبر onRemoved (تضيف أيقونة إغلاق).
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemoved,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  // عند تمريره تُعرض الشريحة محددةً مع أيقونة إزالة.
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final removable = onRemoved != null;
    final filled = selected || removable;
    final fg = filled ? cs.onPrimary : cs.onSurfaceVariant;

    return Material(
      color: filled ? cs.primary : cs.surface,
      shape: StadiumBorder(
        side: filled ? BorderSide.none : BorderSide(color: cs.outline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (removable) ...[
                GestureDetector(
                  onTap: onRemoved,
                  child: AppIcon(AppIcons.x, size: AppSpacing.md, color: fg),
                ),
                const SizedBox(width: 6),
              ],
              Text(label, style: context.text.bodySmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
