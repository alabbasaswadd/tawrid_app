import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// شريط البحث الموحد (Figma: شريط بحث): ارتفاع ٤٨، أيقونة البحث في بداية
// القراءة، ومسح الباركود في الطرف المقابل (يظهر عند تمرير onScanTap).
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    this.controller,
    this.hint = 'ابحث…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onScanTap,
    this.readOnly = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  // لفتح شاشة بحث مخصصة عند الضغط (مع readOnly).
  final VoidCallback? onTap;
  final VoidCallback? onScanTap;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              style: context.text.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (onScanTap != null) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: onScanTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AppIcon(AppIcons.scanBarcode, size: 20, color: cs.primary),
            ),
          ],
        ],
      ),
    );
  }
}
