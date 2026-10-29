import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';

import 'app_icon.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final AppIcons icon;
  final String label;
}

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
        color: cs.primary,
        boxShadow: t.navShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
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

// كل تبويب يملك AnimationController خاصاً — forward عند التفعيل، reverse عند الإلغاء.
// هذا يضمن سلاسة الانتقال حتى لو جرى التبديل السريع بين التبويبات.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // أنيميشن اللون: 0 = غير نشط، 1 = نشط
  late final Animation<double> _colorT;
  // أنيميشن الأيقونة: ينتهي بارتداد خفيف (easeOutBack)
  late final Animation<double> _scaleT;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.active ? 1.0 : 0.0,
    );
    _colorT = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleT = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      widget.active ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final color = Color.lerp(
          cs.onPrimary.withValues(alpha: 0.5),
          cs.onPrimary,
          _colorT.value,
        )!;
        // الأيقونة تنمو من ٨٥٪ إلى ١٠٠٪ مع ارتداد خفيف
        final iconScale = 0.85 + (_scaleT.value * 0.15);

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          splashColor: cs.onPrimary.withValues(alpha: 0.1),
          highlightColor: cs.onPrimary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // المؤشر يكبر من المركز للخارج
                SizedBox(
                  width: 20,
                  height: 3,
                  child: Align(
                    child: Container(
                      width: _colorT.value * 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: cs.onPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Transform.scale(
                  scale: iconScale,
                  child: AppIcon(widget.item.icon, size: 24, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
