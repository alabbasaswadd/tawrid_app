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
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  // compact: يُصغّر الحشو والارتفاع للاستخدام داخل بطاقات القوائم.
  final bool compact;

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
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        // سطر واحد دائماً: زرّان متجاوران في شريط سفلي يُضيّقان بعضهما،
        // فكان «حفظ كمسودة» ينكسر سطرين ويخرج عن ارتفاع الزرّ.
        : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                )
              : Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center));

    final compactStyle = compact
        ? const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 32)),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;

    final Widget btn = switch (variant) {
      AppButtonVariant.filled => FilledButton(
          onPressed: onTap,
          style: compactStyle,
          child: child,
        ),
      AppButtonVariant.tonal => FilledButton.tonal(
          onPressed: onTap,
          style: compactStyle,
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: onTap,
          style: compactStyle,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: onTap,
          style: compactStyle,
          child: child,
        ),
      AppButtonVariant.danger => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ).merge(compactStyle),
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
