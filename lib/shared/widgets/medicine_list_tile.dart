import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/models/enums.dart';

// بطاقة دواء موحّدة — تُستخدم في «أدويتي» وكاتالوج الاختيار.
// شريط لوني جانبي + شارة شكل الجرعة. كل الألوان/الخطوط من الثيم.
// onTap اختياري: عند توفيره تُلفَّف البطاقة بـ InkWell.
class MedicineListTile extends StatelessWidget {
  const MedicineListTile({
    required this.displayName,
    required this.genericName,
    required this.manufacturerName,
    required this.dosageForm,
    this.strength,
    this.subtitleExtra,
    required this.trailing,
    this.onTap,
    super.key,
  });

  final String displayName;
  final String genericName;
  final String manufacturerName;
  final DosageForm dosageForm;
  final double? strength;
  final String? subtitleExtra;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    const radius = BorderRadius.all(Radius.circular(AppRadius.md));

    final meta = [
      genericName,
      manufacturerName,
      if (subtitleExtra != null && subtitleExtra!.isNotEmpty) subtitleExtra!,
    ].where((e) => e.isNotEmpty).join(' · ');

    final decoration = BoxDecoration(
      color: cs.surface,
      borderRadius: radius,
      border: Border.all(color: cs.outline),
      boxShadow: tk.cardShadow,
    );

    final inner = Row(
      children: [
        // شريط اللون الجانبي
        Container(
          width: 4,
          height: 56,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _DosagePill(dosageForm: dosageForm, strength: strength),
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        trailing,
        const SizedBox(width: AppSpacing.sm),
      ],
    );

    if (onTap != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Ink(decoration: decoration, child: inner),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: decoration,
      child: inner,
    );
  }
}

class _DosagePill extends StatelessWidget {
  const _DosagePill({required this.dosageForm, this.strength});
  final DosageForm dosageForm;
  final double? strength;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final label = (strength != null && strength! > 0)
        ? '${dosageForm.label} $strength'
        : dosageForm.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: tk.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
