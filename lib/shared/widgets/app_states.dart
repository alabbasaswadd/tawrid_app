import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// حالات موحّدة متكيّفة مع الثيم (فاتح/داكن). أسماء الأصناف ثابتة حتى لا تتغيّر
// مواضع الاستدعاء عبر التطبيق.

// مؤشّر التحميل الموحّد: شعار توريد نابض + «جارٍ التحميل».
//
// تعريف واحد تستعمله كل الشاشات، فتغييره هنا يغيّرها جميعاً. النبض بطيء
// ولطيف (١٢٠٠ مللي ذهاباً وإياباً) — حركة تقول «يعمل» بلا أن تخطف
// الانتباه عن المحتوى القادم.
class LoadingState extends StatefulWidget {
  const LoadingState({this.message = 'جارٍ التحميل…', super.key});

  /// نصّ بديل حين يكون سبب الانتظار معروفاً: «جارٍ تجهيز الملف…».
  final String message;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            // لا يختفي تماماً: من ٠٫٤٥ إلى ١ يبقي الشعار حاضراً وهو ينبض.
            opacity: Tween<double>(begin: 0.45, end: 1).animate(curve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 84,
                  height: 84,
                  fit: BoxFit.contain,
                  // غياب الأصل لا يجوز أن يُسقط كل شاشة تُحمِّل.
                  errorBuilder: (_, _, _) => Icon(
                      Icons.local_pharmacy_outlined,
                      size: 48,
                      color: context.colors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.message,
              style: context.text.bodySmall?.copyWith(color: tk.hint)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: cs.error, size: 44),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? Icons.inbox_outlined, size: 60, color: context.tokens.hint),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
          ),
        ),
      );
}

class AppSnackbar {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    final bg = isError ? context.colors.error : context.tokens.success;
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  static void success(BuildContext context, String message) => show(context, message);
  static void error(BuildContext context, String message) => show(context, message, isError: true);
}
