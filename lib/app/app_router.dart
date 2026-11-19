import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/role_choice_screen.dart';
import '../features/customer_portal/presentation/screens/customer_home_screen.dart';
import '../features/shop/presentation/screens/shop_dashboard_screen.dart';

/// Route paths from the blueprint (section 8.1). More are added per module.
abstract final class AppRoutes {
  static const chooseRole = '/choose-role';
  static const shopDashboard = '/shop/dashboard';
  static const customerShops = '/customer/shops';
}

/// Route guards here are a convenience only. Real access control is enforced
/// by Firebase rules / the trusted backend (added in module 08-09).
GoRouter createRouter({String initialLocation = AppRoutes.chooseRole}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.chooseRole),
      GoRoute(
        path: AppRoutes.chooseRole,
        builder: (context, state) => const RoleChoiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopDashboard,
        builder: (context, state) => const ShopDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerShops,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
    ],
  );
}
