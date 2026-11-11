import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// نبرة الحالة الدلالية — تُترجَم إلى لون من الثيم (يتكيّف مع الدارك).
enum StatusTone { neutral, brand, success, warning, danger, info }

// شارة حالة موحّدة (pill): خلفية باهتة + نص بلون النبرة.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, this.tone = StatusTone.neutral, this.icon, super.key});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  Color _color(BuildContext context) {
    final t = context.tokens;
    final cs = context.colors;
    return switch (tone) {
      StatusTone.neutral => cs.onSurfaceVariant,
      StatusTone.brand => cs.primary,
      StatusTone.success => t.success,
      StatusTone.warning => t.warning,
      StatusTone.danger => cs.error,
      StatusTone.info => t.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
