import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

class PhShell extends StatelessWidget {
  const PhShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: const [
          AppBottomNavItem(icon: AppIcons.home, label: 'الرئيسية'),
          AppBottomNavItem(icon: AppIcons.clipboardList, label: 'الطلبيات'),
          AppBottomNavItem(icon: AppIcons.fileText, label: 'المناقصات'),
          AppBottomNavItem(icon: AppIcons.tag, label: 'العروض'),
          AppBottomNavItem(icon: AppIcons.user, label: 'حسابي'),
        ],
      ),
    );
  }
}
