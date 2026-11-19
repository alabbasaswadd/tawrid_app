import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';
import 'bonus_badge.dart';
import 'region_rows.dart';

// سياق صف الصنف (Figma: صف صنف العرض): «عرض» للقراءة، «تحرير» داخل
// شاشة إضافة العرض (حذف وتعديل)، «اختيار» بمربع تحديد — الصيدلي يختار
// جزءاً من أصناف العرض وليس ملزماً بكامله.
enum OfferItemRowMode { view, edit, select }

// صف دواء داخل عرض متعدد الأصناف: الاسم والشكل الدوائي، سعر الوحدة،
// والبونص الخاص بالصنف.
class OfferItemRow extends StatelessWidget {
  const OfferItemRow({
    required this.name,
    required this.form,
    required this.unitPrice,
    this.unitPriceLabel = 'سعر الوحدة',
    this.bonusLabel,
    this.availableText,
    this.mode = OfferItemRowMode.view,
    this.onEdit,
    this.onDelete,
    this.selected = false,
    this.onSelectedChanged,
    this.actions = const [],
    super.key,
  });

  // «أموكسيسيلين ٥٠٠ ملغ».
  final String name;

  // «كبسول · ٢٠ كبسولة بالعبوة».
  final String form;
  final String unitPrice;
  final String unitPriceLabel;

  // «بونص ١٠ + ٢» — تُغفل إن لا بونص للصنف.
  final String? bonusLabel;

  // «الكمية المتاحة: ٢٠٠ عبوة» — في سياق العرض فقط.
  final String? availableText;
  final OfferItemRowMode mode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  // لسياق «اختيار» فقط.
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  /// إجراءات الصنف — تُرسَم داخل البطاقة أسفل بياناته بعد فاصل.
  ///
  /// داخلها لا تحتها: زرٌّ طافٍ تحت البطاقة يُقرأ منفصلاً عنها، فلا يَبين
  /// أيّ صنف يخصّ حين تتتابع البطاقات.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الصف الأول: (مربع التحديد في سياق الاختيار) ثم الاسم في بداية
          // القراءة، وكتلة السعر في الطرف المقابل.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mode == OfferItemRowMode.select) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppCheckbox(
                    selection: selected
                        ? AppCheckState.all
                        : AppCheckState.none,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.titleMedium),
                    const SizedBox(height: 1),
                    Text(form, style: context.text.labelSmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(unitPriceLabel, style: context.text.labelSmall),
                  Text(unitPrice, style: context.priceStyle),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // الصف الثاني: البونص في بداية القراءة + (الكمية | إجراءات التحرير).
          Row(
            children: [
              if (bonusLabel != null) BonusBadge(label: bonusLabel!),
              const Spacer(),
              if (mode != OfferItemRowMode.edit && availableText != null)
                Text(availableText!, style: context.text.labelSmall)
              else if (mode == OfferItemRowMode.edit)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: AppIcon(
                        AppIcons.pencil,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: AppIcon(AppIcons.x, size: 16, color: t.danger),
                    ),
                  ],
                ),
            ],
          ),

          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: cs.outline),
            const SizedBox(height: AppSpacing.sm),
            // Wrap لا Row: زرّان بنصّ عربي طويل يفيضان على شاشة ضيّقة،
            // وهنا ينزلان سطراً ثانياً بدل أن يُقصّا.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: actions,
            ),
          ],
        ],
      ),
    );

    if (mode != OfferItemRowMode.select || onSelectedChanged == null) {
      return card;
    }
    return GestureDetector(
      onTap: () => onSelectedChanged!(!selected),
      child: card,
    );
  }
}
