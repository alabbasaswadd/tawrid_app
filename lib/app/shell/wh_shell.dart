import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

class WhShell extends StatelessWidget {
  const WhShell({required this.navigationShell, super.key});

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
        // ترتيب التصميم (Figma: شريط تنقل سفلي/مستودع): الرئيسية، العروض،
        // الطلبات، أدويتي، حسابي. «طلبات التسعير» ليست تبويباً — يُفتح
        // لوحها من عدّاد الرئيسية، لأنه عملٌ دوريّ لا وجهة يومية.
        items: const [
          AppBottomNavItem(icon: AppIcons.home, label: 'الرئيسية'),
          AppBottomNavItem(icon: AppIcons.tag, label: 'العروض'),
          AppBottomNavItem(icon: AppIcons.clipboardList, label: 'الطلبات'),
          AppBottomNavItem(icon: AppIcons.package, label: 'أدويتي'),
          AppBottomNavItem(icon: AppIcons.user, label: 'حسابي'),
        ],
      ),
    );
  }
}
