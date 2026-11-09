import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// عناصر واجهة التصفية — مشتركة بين شاشتي الكتالوج (الوطني
// والمستودعات). نسختان منها كانتا ستفترقان عند أوّل تعديل،
// والفرق في شكل الفلتر يُقرأ عطلاً لا تنوّعاً.

// ── زر الفلاتر الدائري ────────────────────────────────────────────────────
class FiltersBtn extends StatelessWidget {
  const FiltersBtn({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: cs.surface,
          shape: CircleBorder(side: BorderSide(color: cs.outline)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: AppIcon(AppIcons.sliders, size: 18, color: cs.onSurface),
              ),
            ),
          ),
        ),
        if (count > 0)
          PositionedDirectional(
            end: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: tk.brandDeep,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: context.text.labelSmall?.copyWith(
                    color: cs.onPrimary,
                    height: 1,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
class FilterChipCloseable extends StatelessWidget {
  const FilterChipCloseable({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.sm,
        end: AppSpacing.xs,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: tk.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: AppIcon(AppIcons.x, size: 12, color: cs.primary),
          ),
        ],
      ),
    );
  }
}
// ── سطر خيار موحّد في ورقة الفلاتر ──────────────────────────────────────
class FilterOptionRow extends StatelessWidget {
  const FilterOptionRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final AppIcons icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Material(
      color: selected ? tk.brandSurfaceSubtle : cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : tk.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AppIcon(
                    icon,
                    size: 16,
                    color: selected ? cs.onPrimary : cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                AppIcon(AppIcons.check, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
