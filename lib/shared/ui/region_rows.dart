import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// حالة مربع الاختيار الثلاثي: فارغ / جزئي / كامل.
enum AppCheckState { none, partial, all }

// صف محافظة (Figma: صف محافظة): مربع اختيار (كامل/جزئي/فارغ) + الاسم +
// شارة عدد المدن المختارة + سهم توسيع. التوسيع يعرض صفوف المدن تحته.
class GovernorateRow extends StatelessWidget {
  const GovernorateRow({
    required this.name,
    this.selection = AppCheckState.none,
    this.countLabel,
    this.expanded = false,
    this.onTap,
    this.onCheckboxTap,
    super.key,
  });

  final String name;
  final AppCheckState selection;

  // «٣ من ٨» — يظهر فقط عند وجود اختيار.
  final String? countLabel;
  final bool expanded;

  // ضغط الصف (توسيع/طي).
  final VoidCallback? onTap;

  // ضغط مربع الاختيار (تحديد/إلغاء الكل).
  final VoidCallback? onCheckboxTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    final selected = selection != AppCheckState.none;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: selected
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide(color: cs.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              GestureDetector(
                onTap: onCheckboxTap,
                child: AppCheckbox(selection: selection),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(name, style: context.text.titleMedium),
              if (selected && countLabel != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: t.brandSurface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    countLabel!,
                    style: context.text.labelSmall?.copyWith(color: cs.primary),
                  ),
                ),
              ],
              const Spacer(),
              AppIcon(
                expanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// صف مدينة (Figma: صف مدينة): داخل محافظة موسعة — مربع الاختيار في
// بداية القراءة والاسم بجانبه.
class CityRow extends StatelessWidget {
  const CityRow({
    required this.name,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 10,
        ),
        child: Row(
          children: [
            AppCheckbox(
              selection: selected ? AppCheckState.all : AppCheckState.none,
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: context.text.bodySmall?.copyWith(
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// مربع اختيار ٢٠px بزاوية ٦ (Figma): ممتلئ (صح)، جزئي (شرطة)، أو فارغ بحد.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({required this.selection, super.key});

  final AppCheckState selection;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final filled = selection != AppCheckState.none;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: filled ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(6),
        border: filled ? null : Border.all(color: cs.outline, width: 1.5),
      ),
      child: switch (selection) {
        AppCheckState.none => null,
        AppCheckState.all => Center(
          child: AppIcon(AppIcons.check, size: 12, color: cs.onPrimary),
        ),
        AppCheckState.partial => Center(
          child: Container(
            width: 10,
            height: 2,
            decoration: BoxDecoration(
              color: cs.onPrimary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      },
    );
  }
}
