import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/shell/ph_shell.dart';
import 'package:tawrid_app/app/shell/wh_shell.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/core/session/warehouse_session.dart';
import 'package:tawrid_app/features/auth/account_status_page.dart';
import 'package:tawrid_app/features/auth/login_page.dart';
import 'package:tawrid_app/features/dev_gallery/design_gallery_page.dart';
import 'package:tawrid_app/features/ph_cart/ph_cart_page.dart';
import 'package:tawrid_app/features/wh_cart/wh_cart_page.dart';
import 'package:tawrid_app/features/wh_settings/wh_min_order_page.dart';
import 'package:tawrid_app/features/notifications/notification_settings_page.dart';
import 'package:tawrid_app/features/notifications/notifications_page.dart';
import 'package:tawrid_app/features/auth/register_page.dart';
import 'package:tawrid_app/features/ph_home/ph_home_page.dart';
import 'package:tawrid_app/features/ph_medicines/ph_medicine_search_page.dart';
import 'package:tawrid_app/features/ph_more/ph_more_page.dart';
import 'package:tawrid_app/features/ph_offers/ph_offer_detail_page.dart';
import 'package:tawrid_app/features/ph_offers/ph_offers_page.dart';
import 'package:tawrid_app/features/ph_orders/ph_order_detail_page.dart';
import 'package:tawrid_app/features/ph_orders/ph_orders_page.dart';
import 'package:tawrid_app/features/ph_tenders/ph_compare_quotations_page.dart';
import 'package:tawrid_app/features/ph_tenders/ph_create_tender_page.dart';
import 'package:tawrid_app/features/ph_tenders/ph_tenders_page.dart';
import 'package:tawrid_app/features/ph_warehouses/ph_warehouse_profile_page.dart';
import 'package:tawrid_app/features/ph_warehouses/ph_warehouses_page.dart';
import 'package:tawrid_app/features/splash/splash_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_login_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_register_page.dart';
import 'package:tawrid_app/features/wh_auth/wh_service_areas_page.dart';
import 'package:tawrid_app/features/wh_home/wh_home_page.dart';
import 'package:tawrid_app/features/wh_medicines/wh_medicine_catalog_page.dart';
import 'package:tawrid_app/features/wh_medicines/wh_medicines_page.dart';
import 'package:tawrid_app/features/wh_more/wh_more_page.dart';
import 'package:tawrid_app/features/wh_more/wh_profile_page.dart';
import 'package:tawrid_app/features/wh_offers/wh_create_offer_page.dart';
import 'package:tawrid_app/features/wh_offers/wh_offer_detail_page.dart';
import 'package:tawrid_app/features/wh_offers/wh_offers_page.dart';
import 'package:tawrid_app/features/wh_orders/wh_order_detail_page.dart';
import 'package:tawrid_app/features/wh_orders/wh_orders_page.dart';
import 'package:tawrid_app/features/wh_tenders/wh_submit_tender_offer_page.dart';
import 'package:tawrid_app/features/wh_tenders/wh_tenders_page.dart';
import 'package:tawrid_app/features/wh_users/wh_users_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(pharmacySessionProvider, (_, _) => notifyListeners());
    ref.listen(warehouseSessionProvider, (_, _) => notifyListeners());
  }
}

final _refreshNotifierProvider = Provider<_RouterRefreshNotifier>(
  (ref) => _RouterRefreshNotifier(ref),
);

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

      // حساب غير مقبول بعد (قيد المراجعة/مرفوض) → شاشة حالة الحساب تحجب كل شيء.
      final phState = phAsync.value;
      final whState = whAsync.value;
      final phBlocked =
          phState is SessionAuthenticated &&
          phState.accountStatus != AccountStatus.approved;
      final whBlocked =
          whState is WarehouseSessionAuthenticated &&
          whState.accountStatus != AccountStatus.approved;
      if (phBlocked || whBlocked) {
        return loc == TRoutes.accountStatus ? null : TRoutes.accountStatus;
      }
      if (loc == TRoutes.accountStatus) {
        if (phAuth) return TRoutes.phHome;
        if (whAuth) return TRoutes.whHome;
        return TRoutes.phLogin;
      }

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
        TRoutes.phHome,
        TRoutes.phOrders,
        TRoutes.phTenders,
        TRoutes.phOffers,
        TRoutes.phMore,
        TRoutes.phListings,
        TRoutes.phMedicineSearch,
        TRoutes.phNotifications,
        TRoutes.phNotificationSettings,
        TRoutes.phWarehouses,
        TRoutes.phCart,
      };
      // المسارات ذات المعرّف لا تدخل المجموعة الثابتة أعلاه، فتُفحص بالنمط.
      final isPhDetailRoute = (loc.startsWith('/warehouses/') ||
              loc.startsWith('/offers/') ||
              loc.startsWith('/orders/') ||
              loc.startsWith('/tenders/')) &&
          loc.split('/').length == 3;
      if ((phRoutes.contains(loc) || isPhDetailRoute) && !phAuth) {
        return TRoutes.phLogin;
      }

      const whRoutes = {
        TRoutes.whHome,
        TRoutes.whOrders,
        TRoutes.whTenders,
        TRoutes.whOffers,
        TRoutes.whMore,
        TRoutes.whListings,
        TRoutes.whServiceAreas,
        TRoutes.whMedicines,
        TRoutes.whMedicineCatalog,
        TRoutes.whCreateOffer,
        TRoutes.whProfile,
        TRoutes.whUsers,
        TRoutes.whNotifications,
        TRoutes.whNotificationSettings,
        TRoutes.whCart,
        TRoutes.whMinOrder,
      };
      final isSubmitOfferRoute =
          loc.startsWith('/wh/tenders/') && loc.endsWith('/submit-offer');
      // تفاصيل الطلب الوارد: /wh/orders/{id}
      final isWhOrderDetail =
          loc.startsWith('/wh/orders/') && loc.split('/').length == 4;
      // تفاصيل عرض البيع: /wh/offers/{id}
      final isWhOfferDetail =
          loc.startsWith('/wh/offers/') && loc.split('/').length == 4;
      if ((whRoutes.contains(loc) ||
              isSubmitOfferRoute ||
              isWhOrderDetail ||
              isWhOfferDetail) &&
          !whAuth) {
        return TRoutes.whLogin;
      }

      return null;
    },
    routes: [
      GoRoute(path: TRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: TRoutes.phLogin, builder: (_, _) => const PhLoginPage()),
      GoRoute(
        path: TRoutes.phRegister,
        builder: (_, _) => const PhRegisterPage(),
      ),
      GoRoute(path: TRoutes.whLogin, builder: (_, _) => const WhLoginPage()),
      GoRoute(
        path: TRoutes.whRegister,
        builder: (_, _) => const WhRegisterPage(),
      ),

      // معرض نظام التصميم — معاينة المكوّنات أثناء التطوير.
      GoRoute(
        path: TRoutes.devGallery,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const DesignGalleryPage(),
      ),

      // حالة الحساب — قيد المراجعة أو مرفوض (الراوتر يوجّه إليها تلقائياً).
      GoRoute(
        path: TRoutes.accountStatus,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const AccountStatusPage(),
      ),

      // الإشعارات — نفس الشاشة للجهتين، و`isWarehouse` يحدّد الصندوق
      // (وبادئة المسار هي ما يجعل الـinterceptor يرسل التوكن الصحيح).
      GoRoute(
        path: TRoutes.phNotifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsPage(isWarehouse: false),
      ),
      GoRoute(
        path: TRoutes.phNotificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationSettingsPage(isWarehouse: false),
      ),
      GoRoute(
        path: TRoutes.whNotifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationsPage(isWarehouse: true),
      ),
      GoRoute(
        path: TRoutes.whNotificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const NotificationSettingsPage(isWarehouse: true),
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

      // أدوية المستودع (بلا ربط مخزون) + اختيار من الكاتالوج العام
      GoRoute(
        path: TRoutes.whMedicineCatalog,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhMedicineCatalogPage(),
      ),

      // إنشاء عرض بيع — الأصناف تُختار من أدوية المستودع فقط
      GoRoute(
        path: TRoutes.whCreateOffer,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhCreateOfferPage(),
      ),

      // التقدّم بعرض سعر على طلب تسعير مفتوح (من بطاقة الطلب في الصفحة الرئيسية)
      GoRoute(
        path: TRoutes.whSubmitTenderOfferPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => WhSubmitTenderOfferPage(
          tenderId: state.pathParameters['tenderId']!,
        ),
      ),

      // مناطق التخديم — تُعرَض مباشرةً بعد نجاح تسجيل المستودع (top-level، بلا نافبار)
      GoRoute(
        path: TRoutes.whServiceAreas,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhServiceAreasPage(),
      ),

      // الملف الشخصي للمستودع (بيانات + تعديل مناطق التغطية)
      GoRoute(
        path: TRoutes.whProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhProfilePage(),
      ),

      // تفاصيل عرض البيع عند المستودع — شاشة مالك لا شاشة شراء
      GoRoute(
        path: TRoutes.whOfferDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            WhOfferDetailPage(offerId: state.pathParameters['offerId']!),
      ),

      // تفاصيل الطلب الوارد — شاشة قرار لا ورقة قراءة
      GoRoute(
        path: TRoutes.whOrderDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            WhOrderDetailPage(orderId: state.pathParameters['orderId']!),
      ),

      // لوح طلبات التسعير للمستودع — يُفتح من عدّاد الرئيسية لا من تبويب
      GoRoute(
        path: TRoutes.whTenders,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhTendersPage(),
      ),

      // موظّفو المستودع — للمدير فقط (الخادم يفرضها، والمدخل مخفيّ عن الموظّف)
      GoRoute(
        path: TRoutes.whUsers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhUsersPage(),
      ),

      // البحث عن دواء (الصيدلي) — يُفتح من الرئيسية
      GoRoute(
        path: TRoutes.phMedicineSearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const PhMedicineSearchPage(),
      ),

      // سلة الصيدلي
      GoRoute(
        path: TRoutes.phCart,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const PhCartPage(),
      ),

      // سلة المستودع
      GoRoute(
        path: TRoutes.whCart,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhCartPage(),
      ),

      // إعداد الحد الأدنى للطلبية
      GoRoute(
        path: TRoutes.whMinOrder,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const WhMinOrderPage(),
      ),

      // تفاصيل عرض بيع — شاشة كاملة لأن منها تُنشأ الطلبية (اختيار أصناف
      // وكميات)، لا ورقة سفلية للقراءة.
      GoRoute(
        path: TRoutes.phOfferDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            PhOfferDetailPage(offerId: state.pathParameters['offerId']!),
      ),

      // طلبات التسعير: الإنشاء قبل المقارنة — «create» نصٌّ ثابت ولو
      // جاء بعده نمط بمعرّف، فالترتيب هنا يمنع التقاط «create» كمعرّف.
      GoRoute(
        path: TRoutes.phCreateTender,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const PhCreateTenderPage(),
      ),
      GoRoute(
        path: TRoutes.phCompareQuotationsPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => PhCompareQuotationsPage(
          requestId: state.pathParameters['requestId']!,
        ),
      ),

      // تفاصيل طلبية التوريد — المسار والأصناف والفاتورة ومشاركة PDF
      GoRoute(
        path: TRoutes.phOrderDetailPattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            PhOrderDetailPage(orderId: state.pathParameters['orderId']!),
      ),

      // المستودعات المتاحة + ملف مستودع بعينه (يُفتح أيضاً من اسم المستودع
      // في ورقة تفاصيل العرض)
      GoRoute(
        path: TRoutes.phWarehouses,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const PhWarehousesPage(),
      ),
      GoRoute(
        path: TRoutes.phWarehouseProfilePattern,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => PhWarehouseProfilePage(
          warehouseId: state.pathParameters['warehouseId']!,
        ),
      ),

      // Pharmacy shell
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => PhShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.phHome,
                builder: (_, _) => const PhHomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.phOrders,
                builder: (_, _) => const PhOrdersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.phTenders,
                builder: (_, _) => const PhTendersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.phOffers,
                builder: (_, _) => const PhOffersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.phMore,
                builder: (_, _) => const PhMorePage(),
              ),
            ],
          ),
        ],
      ),

      // Warehouse shell
      StatefulShellRoute.indexedStack(
        builder: (context, _, shell) => WhShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.whHome,
                builder: (_, _) => const WhHomePage(),
              ),
            ],
          ),
          // ترتيب الفروع يحدّد ترتيب التبويبات، فيطابق شريط التنقل:
          // الرئيسية، العروض، الطلبات، أدويتي، حسابي.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.whOffers,
                builder: (_, _) => const WhOffersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.whOrders,
                builder: (_, _) => const WhOrdersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.whMedicines,
                builder: (_, _) => const WhMedicinesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: TRoutes.whMore,
                builder: (_, _) => const WhMorePage(),
              ),
            ],
          ),
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
