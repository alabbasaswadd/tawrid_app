import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

// عنصر تبويب سفلي (Figma: عنصر تنقل سفلي).
class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final AppIcons icon;
  final String label;
}

// شريط التنقل السفلي (Figma: شريط تنقل سفلي): ارتفاع ٦٨، سطح أبيض بحد
// علوي وظل خفيف. الحالة النشطة: مؤشر علوي ٢٠×٣ + لون العلامة للأيقونة والنص.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: t.navShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          // الحشوة السفلية ٦ لا ١٠: محتوى العنصر (مؤشر ٣ + أيقونة ٢٤ +
          // تسمية + فواصل) يحتاج ٥١ بكسل، وكانت المساحة ٤٤ فقط — فكان
          // الشريط يُفيض ٧ بكسل بأشرطة التحذير المخططة على الأجهزة التي
          // تُسند الخط العربي إلى بديل أطول سطراً. SafeArea تتكفّل أصلاً
          // بشريط الإيماءات، فالحشوة الزائدة لم تكن تشتري شيئاً.
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: items[i],
                      active: i == currentIndex,
                      onTap: () => onTap(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final color = active ? cs.primary : cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: active ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(height: 4),
            AppIcon(item.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
