import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

class PhShell extends StatefulWidget {
  const PhShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<PhShell> createState() => _PhShellState();
}

class _PhShellState extends State<PhShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  // اتجاه الانزلاق: سالب = من اليسار، موجب = من اليمين (RTL: فهرس أعلى = يسار)
  double _slideDir = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (i != widget.navigationShell.currentIndex) {
      _slideDir = i > widget.navigationShell.currentIndex ? -0.06 : 0.06;
      _ctrl.forward(from: 0.0);
    }
    widget.navigationShell.goBranch(
      i,
      initialLocation: i == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.navigationShell.currentIndex != 0) _onTap(0);
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(_slideDir, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: widget.navigationShell,
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTap,
          items: const [
            AppBottomNavItem(icon: AppIcons.home, label: 'الرئيسية'),
            AppBottomNavItem(icon: AppIcons.clipboardList, label: 'الطلبيات'),
            AppBottomNavItem(icon: AppIcons.fileText, label: 'التسعير'),
            AppBottomNavItem(icon: AppIcons.tag, label: 'العروض'),
            AppBottomNavItem(icon: AppIcons.user, label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}
