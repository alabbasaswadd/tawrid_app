import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// زر رئيسي متدرّج — موحّد على لون الثيم الأساسي. الوسيط [gradient] مُبقى
// للتوافق مع مواضع الاستدعاء القديمة لكنه مُهمَل (اللون يُشتقّ من الثيم).
class TawridButton extends StatelessWidget {
  const TawridButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.gradient,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient? gradient; // مُهمَل
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final enabled = onPressed != null && !loading;
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.22)!],
    );

    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled ? grad : null,
        color: enabled ? null : cs.onSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: cs.onPrimary, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: context.text.titleMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
