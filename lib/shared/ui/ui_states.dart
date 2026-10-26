import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// حالات موحّدة متكيّفة مع الثيم — مطابقة لقسم «الحالات» في Figma.

class UiLoading extends StatelessWidget {
  const UiLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: CircularProgressIndicator(color: context.colors.primary));
}

// حالة فارغة مفيدة (Figma: حالة فارغة): أيقونة قابلة للتبديل + عنوان +
// وصف يقترح الخطوة التالية + زر إجراء واحد. للقوائم الفارغة ونتائج البحث.
class UiEmpty extends StatelessWidget {
  const UiEmpty({
    this.message = 'لا نتائج مطابقة',
    this.description,
    this.appIcon = AppIcons.search,
    this.actionLabel,
    this.onAction,
    this.icon,
    super.key,
  });

  final String message;

  // «جرّب تعديل كلمات البحث أو إزالة بعض الفلاتر».
  final String? description;
  final AppIcons appIcon;

  // «مسح الفلاتر» — زر الإجراء يظهر فقط مع onAction.
  final String? actionLabel;
  final VoidCallback? onAction;

  // أيقونة Material قديمة — تحل محل appIcon إن مُرِّرت (توافقاً).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: t.brandSurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 34, color: cs.primary)
                    : AppIcon(appIcon, size: 34, color: cs.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 280,
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 10),
              _StateButton(label: actionLabel!, onTap: onAction!, filled: true),
            ],
          ],
        ),
      ),
    );
  }
}

// حالة خطأ قابلة لإعادة المحاولة (Figma: حالة خطأ): أيقونة تنبيه حمراء +
// عنوان + وصف + زر ثانوي لإعادة المحاولة.
class UiError extends StatelessWidget {
  const UiError({
    this.message = 'تعذّر تحميل البيانات',
    this.description = 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة',
    this.retryLabel = 'إعادة المحاولة',
    this.onRetry,
    super.key,
  });

  final String message;
  final String? description;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: t.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.alertTriangle,
                  size: 34,
                  color: t.danger,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 280,
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              _StateButton(label: retryLabel, onTap: onRetry!, filled: false),
            ],
          ],
        ),
      ),
    );
  }
}

// زر الحالة المصغّر: ممتلئ (أساسي) أو بحد أخضر (ثانوي) — px18 py9 زاوية 10.
class _StateButton extends StatelessWidget {
  const _StateButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Material(
      color: filled ? cs.primary : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled
            ? BorderSide.none
            : BorderSide(color: cs.primary, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: filled ? cs.onPrimary : cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// هيكل تحميل بشكل بطاقة العرض (Figma: هيكل تحميل/بطاقة عرض) —
// يُكرر أثناء جلب القوائم بدل مؤشر دوار وحيد.
class OfferCardSkeleton extends StatelessWidget {
  const OfferCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    Widget block(double w, double h, double r) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.outline,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [block(150, 14, 6), block(72, 22, AppRadius.full)],
          ),
          const SizedBox(height: 10),
          Row(children: [block(210, 10, 6)]),
          const SizedBox(height: 10),
          Row(children: [block(160, 10, 6)]),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(60, 9, 6),
                  const SizedBox(height: 5),
                  block(90, 14, 6),
                ],
              ),
              const Spacer(),
              block(110, 32, 10),
            ],
          ),
        ],
      ),
    );
  }
}
