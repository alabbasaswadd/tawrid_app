import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// الشريط العلوي الترحيبي (Figma: شريط علوي/ترحيب) — تحية + اسم الجهة في
// بداية القراءة، وزر إشعارات دائري في الطرف المقابل مع نقطة غير المقروء.
class WelcomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const WelcomeTopBar({
    required this.greeting,
    required this.name,
    this.onNotificationsTap,
    this.hasUnread = false,
    this.onCartTap,
    this.cartCount = 0,
    super.key,
  });

  final String greeting;
  final String name;
  final VoidCallback? onNotificationsTap;
  final bool hasUnread;
  final VoidCallback? onCartTap;
  final int cartCount;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: context.text.bodySmall),
                  Text(name, style: context.text.titleLarge),
                ],
              ),
            ),
            if (onCartTap != null) ...[
              Stack(
                children: [
                  Material(
                    color: cs.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onCartTap,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: AppIcon(
                            AppIcons.shoppingCart,
                            size: 20,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (cartCount > 0)
                    PositionedDirectional(
                      end: 2,
                      top: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            cartCount > 9 ? '9+' : '$cartCount',
                            style: context.text.labelSmall?.copyWith(
                              color: cs.onPrimary,
                              fontSize: 9,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Stack(
              children: [
                Material(
                  color: cs.surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onNotificationsTap,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AppIcon(
                          AppIcons.bell,
                          size: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasUnread)
                  PositionedDirectional(
                    end: 2,
                    top: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// الشريط العلوي للشاشات الداخلية (Figma: شريط علوي/داخلي) —
// زر رجوع دائري في بداية القراءة وعنوان في الوسط وموازن في الطرف الآخر.
class InnerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const InnerTopBar({
    required this.title,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;

  // الافتراضي: Navigator.maybePop.
  final VoidCallback? onBack;

  // عنصر اختياري مكان الموازن (مثل زر إجراء).
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        child: Row(
          children: [
            Material(
              color: cs.surface,
              shape: CircleBorder(side: BorderSide(color: cs.outline)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: AppIcon(
                      AppIcons.chevronBackRtl,
                      size: 20,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 40, height: 40, child: trailing),
          ],
        ),
      ),
    );
  }
}
