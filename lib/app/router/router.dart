import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/shell/ph_shell.dart';
import 'package:tawrid_app/app/shell/wh_shell.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/features/auth/login_page.dart';
import 'package:tawrid_app/features/auth/register_page.dart';
import 'package:tawrid_app/features/ph_home/ph_home_page.dart';
import 'package:tawrid_app/features/ph_more/ph_more_page.dart';
import 'package:tawrid_app/features/ph_offers/ph_offers_page.dart';
import 'package:tawrid_app/features/ph_orders/ph_orders_page.dart';
import 'package:tawrid_app/features/ph_tenders/ph_tenders_page.dart';
import 'package:tawrid_app/features/splash/splash_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_login_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_register_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_service_areas_page.dart';
import 'package:tawrid_app/features/wh_home/wh_home_page.dart';
import 'package:tawrid_app/features/wh_more/wh_more_page.dart';
import 'package:tawrid_app/features/wh_offers/wh_offers_page.dart';
import 'package:tawrid_app/features/wh_orders/wh_orders_page.dart';
import 'package:tawrid_app/features/wh_tenders/wh_tenders_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(pharmacySessionProvider, (_, _) => notifyListeners());
    ref.listen(warehouseSessionProvider, (_, _) => notifyListeners());
  }
}

final _refreshNotifierProvider =
    Provider<_RouterRefreshNotifier>((ref) => _RouterRefreshNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_refreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: TRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final phAsync = ref.read(pharmacySessionProvider);
      final whAsync = ref.read(warehouseSessionProvider);
      final loc = state.matchedLocation;

      if (phAsync.isLoading || whAsync.isLoading) {
        return loc == TRoutes.splash ? null : TRoutes.splash;
      }

      final phAuth = switch (phAsync) {
        AsyncData(:final value) => value is SessionAuthenticated,
        _ => false,
      };
      final whAuth = switch (whAsync) {
        AsyncData(:final value) => value is WarehouseSessionAuthenticated,
        _ => false,
      };

      if (loc == TRoutes.splash) {
        if (phAuth) return TRoutes.phHome;
        if (whAuth) return TRoutes.whHome;
        return TRoutes.phLogin;
      }

      if (loc == TRoutes.phLogin || loc == TRoutes.phRegister) {
        if (phAuth) return TRoutes.phHome;
      }

      if (loc == TRoutes.whLogin || loc == TRoutes.whRegister) {
        if (whAuth) return TRoutes.whHome;
      }

      const phRoutes = {
        TRoutes.phHome, TRoutes.phOrders, TRoutes.phTenders,
        TRoutes.phOffers, TRoutes.phMore, TRoutes.phListings,
      };
      if (phRoutes.contains(loc) && !phAuth) return TRoutes.phLogin;

      const whRoutes = {
        TRoutes.whHome, TRoutes.whOrders, TRoutes.whTenders,
        TRoutes.whOffers, TRoutes.whMore, TRoutes.whListings,
        TRoutes.whServiceAreas,
      };
      if (whRoutes.contains(loc) && !whAuth) return TRoutes.whLogin;

      return null;
    },
    routes: [
      GoRoute(
        path: TRoutes.splash,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: TRoutes.phLogin,
        builder: (_, _) => const PhLoginPage(),
      ),
      GoRoute(
        path: TRoutes.phRegister,
        builder: (_, _) => const PhRegisterPage(),
      ),
      GoRoute(
        path: TRoutes.whLogin,
        builder: (_, _) => const WhLoginPage(),
      ),
      GoRoute(
        path: TRoutes.whRegister,
        builder: (_, _) => const WhRegisterPage(),
      ),

      // Pharmacy listings — top-level, pushes over the shell (no nav bar)
      GoRoute(
        path: TRoutes.phListings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const _PlaceholderPage(title: 'إعلاناتي'),
      ),

      // Warehouse listings — top-level, pushes over the shell (no nav bar)
      GoRoute(
        path: TRoutes.whListings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const _PlaceholderPage(title: 'إعلانات المستودع'),
      ),

      // مناطق التخديم — تُعرَض مباشرةً بعد نجاح تسجيل المستودع (top-level، بلا نافبار)
      GoRoute(
        path: TRoutes.whServiceAreas,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhServiceAreasPage(),
      ),

      // Pharmacy shell
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => PhShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.phHome,
              builder: (_, _) => const PhHomePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.phOrders,
              builder: (_, _) => const PhOrdersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.phTenders,
              builder: (_, _) => const PhTendersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.phOffers,
              builder: (_, _) => const PhOffersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.phMore,
              builder: (_, _) => const PhMorePage(),
            ),
          ]),
        ],
      ),

      // Warehouse shell
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => WhShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.whHome,
              builder: (_, _) => const WhHomePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.whOrders,
              builder: (_, _) => const WhOrdersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.whTenders,
              builder: (_, _) => const WhTendersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.whOffers,
              builder: (_, _) => const WhOffersPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: TRoutes.whMore,
              builder: (_, _) => const WhMorePage(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text('$title — قريباً')),
      );
}
