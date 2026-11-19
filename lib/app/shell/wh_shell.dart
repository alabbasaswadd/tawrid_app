import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

class WhShell extends ConsumerStatefulWidget {
  const WhShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<WhShell> createState() => _WhShellState();
}

class _WhShellState extends ConsumerState<WhShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  double _slideDir = 0.0;

  static const int _tabCount = 5;

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

  void _onSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final cur = widget.navigationShell.currentIndex;
    if (v > 300 && cur < _tabCount - 1) {
      _onTap(cur + 1);
    } else if (v < -300 && cur > 0) {
      _onTap(cur - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread =
        (ref.watch(whUnreadConversationsProvider).value ?? 0) > 0;

    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.navigationShell.currentIndex != 0) _onTap(0);
      },
      child: Scaffold(
        body: GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(_slideDir, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
            child: widget.navigationShell,
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTap,
          items: [
            const AppBottomNavItem(icon: AppIcons.home, label: 'الرئيسية'),
            const AppBottomNavItem(icon: AppIcons.clipboardList, label: 'الطلبات'),
            AppBottomNavItem(
              icon: AppIcons.messageSquare,
              label: 'الرسائل',
              showBadge: hasUnread,
            ),
            const AppBottomNavItem(icon: AppIcons.package, label: 'أدويتي'),
            const AppBottomNavItem(icon: AppIcons.user, label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}
