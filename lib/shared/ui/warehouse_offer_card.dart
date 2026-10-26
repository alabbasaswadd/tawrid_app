import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';
import 'status_badge.dart';

// بطاقة إدارة العرض في تطبيق المستودع (Figma: بطاقة عرض المستودع):
// الحالة (منشور/مسودة/متوقف/ينتهي قريباً)، الأصناف والبونص، تاريخ
// الانتهاء، وإجراءا تعديل وإيقاف. تختلف عن بطاقة عرض الصيدلي التي
// تركز على الشراء.
class WarehouseOfferCard extends StatelessWidget {
  const WarehouseOfferCard({
    required this.title,
    required this.itemsText,
    required this.expiryText,
    required this.statusLabel,
    this.statusTone = StatusTone.success,
    this.lastUpdateText,
    this.editLabel = 'تعديل',
    this.stopLabel = 'إيقاف',
    this.onEdit,
    this.onStop,
    this.onTap,
    super.key,
  });

  final String title;

  // «٥ أصناف · بونص أصناف + ٥٪ على كامل العرض».
  final String itemsText;
  final String expiryText;

  // «منشور» / «مسودة» / «متوقف»… — مع نبرتها.
  final String statusLabel;
  final StatusTone statusTone;

  // «آخر تحديث: اليوم».
  final String? lastUpdateText;
  final String editLabel;
  final String stopLabel;
  final VoidCallback? onEdit;

  // إيقاف العرض — يُغفل الإجراء بإغفال الـ callback.
  final VoidCallback? onStop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: t.cardShadow,
      ),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: context.text.titleMedium),
                    ),
                    StatusBadge(label: statusLabel, tone: statusTone),
                  ],
                ),
                const SizedBox(height: 10),
                _Meta(icon: AppIcons.package, text: itemsText),
                const SizedBox(height: 10),
                _Meta(icon: AppIcons.clock, text: expiryText),
                const SizedBox(height: 10),
                Divider(color: cs.outline),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (lastUpdateText != null)
                      Expanded(
                        child: Text(
                          lastUpdateText!,
                          style: context.text.labelSmall,
                        ),
                      )
                    else
                      const Spacer(),
                    _Action(
                      icon: AppIcons.pencil,
                      label: editLabel,
                      color: cs.primary,
                      onTap: onEdit,
                    ),
                    if (onStop != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      _Action(
                        icon: AppIcons.x,
                        label: stopLabel,
                        color: t.danger,
                        onTap: onStop,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final AppIcons icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.onSurfaceVariant;
    return Row(
      children: [
        AppIcon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final AppIcons icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: context.text.bodySmall?.copyWith(color: color)),
          const SizedBox(width: 4),
          AppIcon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}
