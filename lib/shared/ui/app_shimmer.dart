import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

// هياكل التحميل المتلألئة (shimmer skeletons) — المصدر المركزي الوحيد.
// كل الألوان من context.tokens فتتكيّف مع الفاتح/الداكن وتحمل لمسة
// العلامة الخفيفة. الهياكل تطابق شكل البطاقات الحقيقية (نفس نصف القطر
// AppRadius.lg، الحدّ، الظل، الحشوة) ليبدو الانتقال من الهيكل إلى
// المحتوى سلساً دون «قفزة».
//
// الاستعمال في الشاشات (بديل LoadingState):
//   if (_loading) return const AppListSkeleton();              // قوائم بطاقات
//   if (_loading) return const AppListSkeleton(variant: SkeletonVariant.row); // قوائم صفوف
//   if (_loading) return const AppDetailSkeleton();            // تفاصيل/نماذج/ملف

// ===== الغلاف الأساسي =====

// يطبّق تأثير اللمعان على شجرة الهيكل. يُلفّ مرة واحدة حول القائمة كلها
// (أداءً أفضل من لفّ كل عنصر). base = السطح البديل، highlight أفتح منه
// (أبيض السطح في الفاتح، حدّ قوي في الداكن).
class AppShimmer extends StatelessWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cs = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Shimmer.fromColors(
        baseColor: t.surfaceAlt,
        highlightColor: dark ? t.outlineStrong : cs.surface,
        period: const Duration(milliseconds: 1400),
        child: child,
      ),
    );
  }
}

// لبنة الهيكل: مستطيل مصمت بلون السطح البديل (يُقنَّع باللمعان فوقه).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({this.width, this.height = 12, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// دائرة هيكلية (صورة رمزية / أيقونة دائرية).
class _ShimmerCircle extends StatelessWidget {
  const _ShimmerCircle();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.tokens.surfaceAlt,
          shape: BoxShape.circle,
        ),
      );
}

// إطار بطاقة هيكلية — نفس كروم البطاقات الحقيقية (سطح + حدّ + ظل + زوايا).
class _SkeletonFrame extends StatelessWidget {
  const _SkeletonFrame({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline),
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }
}

enum SkeletonVariant { card, row }

// ===== قائمة هياكل =====

// بديل LoadingState في شاشات القوائم: ListView من بطاقات/صفوف هيكلية.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    this.variant = SkeletonVariant.card,
    this.count = 6,
    this.padding,
    super.key,
  });

  final SkeletonVariant variant;
  final int count;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final isRow = variant == SkeletonVariant.row;
    return AppShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ??
            const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.x3l),
        itemCount: count,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: isRow ? const _SkeletonRow() : const _SkeletonCard(),
        ),
      ),
    );
  }
}

// بطاقة هيكلية — عنوان + شارة، سطرا معاينة، فاصل، زر إجراء. تحاكي
// OfferCard/OrderCard/TenderCard/WarehouseOfferCard.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return _SkeletonFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 170, height: 15, radius: 7),
                    SizedBox(height: 8),
                    ShimmerBox(width: 110, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 10),
              ShimmerBox(width: 64, height: 24, radius: 999),
            ],
          ),
          SizedBox(height: 16),
          ShimmerBox(height: 12),
          SizedBox(height: 8),
          ShimmerBox(width: 210, height: 12),
          SizedBox(height: 16),
          ShimmerBox(height: 1, radius: 0),
          SizedBox(height: 14),
          ShimmerBox(height: 40, radius: 12),
        ],
      ),
    );
  }
}

// صف هيكلي — دائرة + سطران + شارة. يحاكي صفوف الأدوية/المستخدمين/الإشعارات.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return _SkeletonFrame(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: const [
          _ShimmerCircle(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 14, radius: 7),
                SizedBox(height: 8),
                ShimmerBox(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: 10),
          ShimmerBox(width: 52, height: 22, radius: 999),
        ],
      ),
    );
  }
}

// ===== هيكل تفاصيل/نموذج =====

// بديل LoadingState في شاشات التفاصيل والنماذج والملفات: رأس كبير +
// بنود + شريط إجمالي + زر. قابل للتمرير حتى لا يفيض على الشاشات القصيرة.
class AppDetailSkeleton extends StatelessWidget {
  const AppDetailSkeleton({this.padding, super.key});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ??
            const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.x3l),
        children: [
          // رأس: عنوان + حالة + سطر وصفي.
          _SkeletonFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Row(
                  children: [
                    Expanded(child: ShimmerBox(width: 180, height: 18, radius: 8)),
                    SizedBox(width: 10),
                    ShimmerBox(width: 70, height: 26, radius: 999),
                  ],
                ),
                SizedBox(height: 12),
                ShimmerBox(height: 12),
                SizedBox(height: 8),
                ShimmerBox(width: 160, height: 12),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // بنود.
          _SkeletonFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Row(
                    children: const [
                      Expanded(child: ShimmerBox(width: 120, height: 13)),
                      SizedBox(width: 24),
                      ShimmerBox(width: 64, height: 13),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // شريط الإجمالي.
          _SkeletonFrame(
            child: Row(
              children: const [
                ShimmerBox(width: 90, height: 16, radius: 8),
                Spacer(),
                ShimmerBox(width: 110, height: 20, radius: 8),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // زر الإجراء.
          const ShimmerBox(height: 52, radius: 12),
        ],
      ),
    );
  }
}
