import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// زر أيقونة دائري ٤٠×٤٠ (Figma: أزرار الشريط العلوي) — سطح أبيض وحدّ
// اختياري. الشكل نفسه يتكرر في الشريط العلوي وشريط العروض، فعُرّف مرة.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.bordered = false,
    this.size = 20,
    super.key,
  });

  final AppIcons icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// حدّ رمادي رفيع — يُستخدم حين يقع الزر على خلفية الصفحة لا على سطح.
  final bool bordered;

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    final button = Material(
      color: cs.surface,
      shape: bordered
          ? CircleBorder(side: BorderSide(color: cs.outline))
          : const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AppIcon(icon, size: size, color: cs.onSurface),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
