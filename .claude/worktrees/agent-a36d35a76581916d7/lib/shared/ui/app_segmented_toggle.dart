import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/app/theme/tokens.dart';

class SegmentItem {
  const SegmentItem({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

// مفتاح تبديل مقطعي موحّد — المقطع المحدّد بخلفية أساسية ونص onPrimary،
// وغير المحدّد بخلفية سطح بديل ونص ثانوي (تباين واضح، يتكيّف مع الدارك).
class AppSegmentedToggle extends StatelessWidget {
  const AppSegmentedToggle({
    required this.items,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<SegmentItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(child: _segment(context, i, items[i])),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int index, SegmentItem item) {
    final cs = context.colors;
    final active = selected == index;
    return GestureDetector(
      onTap: () => onChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 18, color: active ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: active ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
