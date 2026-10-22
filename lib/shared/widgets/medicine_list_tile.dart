import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/models/enums.dart';

// بطاقة دواء مُوحَّدة — تُستخدم في قائمة "أدويتي" وفي كاتالوج الاختيار،
// بتصميم أكثر كثافة وقابلية للمسح البصري (شريط لوني جانبي بدل الأفاتار
// الدائري، وشارة شكل جرعة مختصرة) بدل صفوف ListTile العادية.
class MedicineListTile extends StatelessWidget {
  const MedicineListTile({
    required this.displayName,
    required this.genericName,
    required this.manufacturerName,
    required this.dosageForm,
    this.strength,
    this.subtitleExtra,
    required this.trailing,
    super.key,
  });

  final String displayName;
  final String genericName;
  final String manufacturerName;
  final DosageForm dosageForm;
  final double? strength;
  final String? subtitleExtra;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final meta = [
      genericName,
      manufacturerName,
      if (subtitleExtra != null && subtitleExtra!.isNotEmpty) subtitleExtra!,
    ].where((e) => e.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: TawridColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TawridColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 52,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: TawridColors.warehouse,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      const SizedBox(width: 6),
                      _DosagePill(dosageForm: dosageForm, strength: strength),
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(fontSize: 11.5, color: TawridColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          trailing,
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _DosagePill extends StatelessWidget {
  const _DosagePill({required this.dosageForm, this.strength});
  final DosageForm dosageForm;
  final double? strength;

  @override
  Widget build(BuildContext context) {
    final label = (strength != null && strength! > 0)
        ? '${dosageForm.label} $strength'
        : dosageForm.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: TawridColors.warehouse.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(label,
          style: GoogleFonts.cairo(
              fontSize: 10.5, color: TawridColors.warehouse, fontWeight: FontWeight.w700)),
    );
  }
}
