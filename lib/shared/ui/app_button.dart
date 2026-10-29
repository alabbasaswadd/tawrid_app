import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'dots_loader.dart';

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

    // محتوى الحالة العادية — يُبنى دائماً، ويُستعمل أثناء الانتظار شفافاً
    // ليحجز المقاس نفسه: الزرّ لا يقفز بين حالتيه ولا ينكمش حول ثلاث نقاط
    // فيبدو شريطاً عريضاً مسطّحاً.
    final Widget label = icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: compact ? 14 : 18),
                    SizedBox(width: compact ? 6 : 8),
                    Flexible(
                      child: Text(this.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                )
        : Text(this.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center);

    // أثناء الانتظار: النقاط فوق النصّ المخفيّ — نفس العرض ونفس الارتفاع.
    final Widget child = loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, child: label),
              DotsLoader(color: spinnerColor, size: compact ? 5 : 6),
            ],
          )
        : label;

    // الارتفاع يأتي من الثيم وحده (Figma: ٤٨ وحشو أفقي ٢٤) — لا يُعاد
    // تعريفه هنا، وإلا لم يُطبَّق مقاس Figma في أي زرّ بالتطبيق لأن هذا
    // المكوّن هو كل الأزرار.
    const baseStyle = ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // compact: زرّ داخل بطاقة (Figma: حشو ١٤×٨ بنصّ ١٢ ⇒ ارتفاع ٣٤).
    // النصّ يصغر مع الصندوق: ترك نصّ الزرّ ١٥ داخل ارتفاع ٣٤ يملأ الزرّ
    // حرفاً بلا هامش، فيبدو مضغوطاً لا صغيراً.
    final compactStyle = compact
        ? ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(0, AppSizes.buttonHeightCompact),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSizes.buttonPaddingXCompact),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStatePropertyAll(context.text.bodySmall),
          )
        : baseStyle;

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
