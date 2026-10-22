import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// ترويسة قسم موحّدة — عنوان + أيقونة اختيارية + إجراء جانبي اختياري.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({required this.title, this.icon, this.trailing, this.subtitle, super.key});

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.colors.primary),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(title, style: context.text.titleSmall)),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: context.text.bodySmall),
        ],
      ],
    );
  }
}
