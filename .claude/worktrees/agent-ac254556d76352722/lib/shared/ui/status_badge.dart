import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// نبرة الحالة الدلالية — تُترجَم إلى لون نص + سطح باهت من الثيم.
enum StatusTone { neutral, brand, success, warning, danger, info }

// شارة حالة موحّدة (Figma: شارة حالة) — pill بسطح باهت، نص ١٢ + نقطة ٦px
// في بداية القراءة. لا تعتمد على اللون وحده (نص + نقطة معاً).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;

  // أيقونة اختيارية تحل محل النقطة (استخدام قديم).
  final IconData? icon;

  (Color fg, Color bg) _palette(BuildContext context) {
    final t = context.tokens;
    final cs = context.colors;
    return switch (tone) {
      StatusTone.neutral => (
        cs.onSurfaceVariant,
        Theme.of(context).scaffoldBackgroundColor,
      ),
      StatusTone.brand => (cs.primary, t.brandSurface),
      StatusTone.success => (t.success, t.successSurface),
      StatusTone.warning => (t.warning, t.warningSurface),
      StatusTone.danger => (t.danger, t.dangerSurface),
      StatusTone.info => (t.info, t.info.withValues(alpha: 0.12)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: tone == StatusTone.neutral
            ? Border.all(color: context.colors.outline)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(label, style: context.text.bodySmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
