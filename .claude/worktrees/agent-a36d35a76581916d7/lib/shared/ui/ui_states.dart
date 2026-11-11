import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// حالات موحّدة متكيّفة مع الثيم (بدائل theme-aware لـ app_states القديمة).

class UiLoading extends StatelessWidget {
  const UiLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: CircularProgressIndicator(color: context.colors.primary));
}

class UiEmpty extends StatelessWidget {
  const UiEmpty({required this.message, this.icon = Icons.inbox_outlined, super.key});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: context.tokens.hint),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            ],
          ),
        ),
      );
}

class UiError extends StatelessWidget {
  const UiError({required this.message, this.onRetry, super.key});
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
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(Icons.error_outline, color: cs.error, size: 44),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}
