import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// عداد مختصر لملخص العمل (Figma: عداد ملخص): رقم + تسمية + أيقونة دائرية
// على سطح العلامة. يُستخدم في صف أو شبكة ثنائية.
class SummaryCounter extends StatelessWidget {
  const SummaryCounter({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final AppIcons icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Material(
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
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(icon, size: 18, color: cs.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: context.priceStyle),
                    Text(label, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
