import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/role_choice_screen.dart';
import '../features/customer_portal/presentation/screens/customer_home_screen.dart';
import '../features/customers/presentation/screens/add_edit_customer_screen.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';
import '../features/customers/presentation/screens/customer_list_screen.dart';
import '../features/payments/presentation/screens/record_payment_screen.dart';
import '../features/products/presentation/screens/add_edit_product_screen.dart';
import '../features/products/presentation/screens/product_list_screen.dart';
import '../features/sales/presentation/screens/new_sale_screen.dart';
import '../features/sales/presentation/screens/sale_detail_screen.dart';
import '../features/shop/presentation/screens/shop_dashboard_screen.dart';
import '../features/shop/presentation/screens/shop_edit_screen.dart';
import '../features/shop/presentation/screens/shop_setup_screen.dart';

/// Route paths from the blueprint (section 8.1).
abstract final class AppRoutes {
  static const chooseRole = '/choose-role';
  static const shopDashboard = '/shop/dashboard';
  static const shopSetup = '/shop/setup';
  static const shopEdit = '/shop/edit';
  static const customerList = '/shop/customers';
  static const customerNew = '/shop/customers/new';
  static const productList = '/shop/products';
  static const productNew = '/shop/products/new';
  static const saleNew = '/shop/sales/new';
  static const paymentNew = '/shop/payments/new';
  static const customerShops = '/customer/shops';
}

/// Route definitions for EasyHisab.
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
        path: AppRoutes.shopSetup,
        builder: (context, state) => const ShopSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopEdit,
        builder: (context, state) => const ShopEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerList,
        builder: (context, state) => const CustomerListScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerNew,
        builder: (context, state) => const AddEditCustomerScreen(),
      ),
      GoRoute(
        path: '/shop/customers/:id',
        builder: (context, state) => CustomerDetailScreen(
          customerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/shop/customers/:id/edit',
        builder: (context, state) => AddEditCustomerScreen(
          customerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.productList,
        builder: (context, state) => const ProductListScreen(),
      ),
      GoRoute(
        path: AppRoutes.productNew,
        builder: (context, state) => const AddEditProductScreen(),
      ),
      GoRoute(
        path: '/shop/products/:id/edit',
        builder: (context, state) => AddEditProductScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.saleNew,
        builder: (context, state) => NewSaleScreen(
          initialCustomerId: state.uri.queryParameters['customerId'],
        ),
      ),
      GoRoute(
        path: '/shop/sales/:id',
        builder: (context, state) => SaleDetailScreen(
          saleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentNew,
        builder: (context, state) => RecordPaymentScreen(
          initialCustomerId: state.uri.queryParameters['customerId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.customerShops,
        builder: (context, state) => const CustomerHomeScreen(),
      ),
    ],
  );
}
