import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// شارة البونص الذهبية (Figma: شارة بونص) — تُستخدم فقط لإبراز البونص
// والعروض المميزة. compact: نسخة أصغر بلا أيقونة لرأس بطاقة العرض.
class BonusBadge extends StatelessWidget {
  const BonusBadge({required this.label, this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textStyle = compact
        ? context.text.labelSmall?.copyWith(
            color: t.goldStrong,
            fontWeight: FontWeight.w400,
          )
        : context.text.bodySmall?.copyWith(color: t.goldStrong);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: t.goldSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: t.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            AppIcon(AppIcons.gift, size: 14, color: t.goldStrong),
            const SizedBox(width: 6),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}
