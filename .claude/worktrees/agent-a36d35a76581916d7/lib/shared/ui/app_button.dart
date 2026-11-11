import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

enum AppButtonVariant { filled, tonal, outline, text, danger }

// زر موحّد فوق أزرار Material المنسّقة بالثيم — يضيف أنماطاً + حالة تحميل + عرض كامل.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final onTap = loading ? null : onPressed;

    final spinnerColor = switch (variant) {
      AppButtonVariant.filled || AppButtonVariant.danger => cs.onPrimary,
      _ => cs.primary,
    };

    final Widget child = loading
        ? SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
              )
            : Text(label));

    final Widget btn = switch (variant) {
      AppButtonVariant.filled => FilledButton(onPressed: onTap, child: child),
      AppButtonVariant.tonal => FilledButton.tonal(onPressed: onTap, child: child),
      AppButtonVariant.outline => OutlinedButton(onPressed: onTap, child: child),
      AppButtonVariant.text => TextButton(onPressed: onTap, child: child),
      AppButtonVariant.danger => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
