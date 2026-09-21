import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/billing/presentation/billing_screen.dart';
import '../features/business_selection/presentation/business_selection_screen.dart';
import '../features/business_selection/providers/business_provider.dart';
import '../features/clothing/barcode/presentation/barcode_scanner_screen.dart';
import '../features/clothing/products/presentation/products_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/invoices/presentation/invoice_detail_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/bluetooth_printer_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../models/business.dart';
import '../shared/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Keep one router instance — recreating GoRouter is very expensive.
  ref.keepAlive();

  final authNotifier = _AuthRefreshNotifier();

  ref.listen<bool>(isAuthenticatedProvider, (prev, next) {
    if (prev != next) authNotifier.refresh();
  });
  ref.listen<Business?>(activeBusinessProvider, (prev, next) {
    if (prev?.id != next?.id) authNotifier.refresh();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final activeBusiness = ref.read(activeBusinessProvider);
      final path = state.matchedLocation;

      final isLogin = path == '/login';
      final isBusinessSelection = path == '/business-selection';

      if (!isAuthenticated) {
        return isLogin ? null : '/login';
      }

      if (isLogin) {
        return activeBusiness == null ? '/business-selection' : '/dashboard';
      }

      if (activeBusiness == null && !isBusinessSelection) {
        return '/business-selection';
      }

      if (isBusinessSelection && activeBusiness != null) {
        return '/dashboard';
      }

      if (path == '/barcode-scanner' && activeBusiness != null && !activeBusiness.isClothing) {
        return '/billing';
      }

      if (path == '/products' && activeBusiness != null && !activeBusiness.isClothing) {
        return '/more';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/business-selection',
        builder: (context, state) => const BusinessSelectionScreen(),
      ),
      GoRoute(
        path: '/barcode-scanner',
        builder: (context, state) => const BarcodeScannerScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/bluetooth-printer',
        builder: (context, state) => const BluetoothPrinterScreen(),
      ),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final printBt = state.uri.queryParameters['print'] == 'bt';
          return InvoiceDetailScreen(invoiceId: id, autoPrintBt: printBt);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/billing',
                builder: (context, state) => const BillingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoicesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
