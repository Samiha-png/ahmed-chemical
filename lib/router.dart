import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/adjust_stock_screen.dart';
import 'screens/balance_sheet_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/chart_of_accounts_screen.dart';
import 'screens/currencies_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/customer_form_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/goods_receipt_detail_screen.dart';
import 'screens/goods_receipt_form_screen.dart';
import 'screens/goods_receipts_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/journal_entries_screen.dart';
import 'screens/journal_entry_detail_screen.dart';
import 'screens/journal_entry_form_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profit_loss_screen.dart';
import 'screens/purchase_order_detail_screen.dart';
import 'screens/purchase_order_form_screen.dart';
import 'screens/purchase_orders_screen.dart';
import 'screens/receive_stock_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/role_form_screen.dart';       // ← NEW (banayenge)
import 'screens/roles_screen.dart';           // ← NEW (banayenge)
import 'screens/sales_invoice_detail_screen.dart';
import 'screens/sales_invoice_form_screen.dart';
import 'screens/sales_invoices_screen.dart';
import 'screens/sales_order_detail_screen.dart';
import 'screens/sales_order_form_screen.dart';
import 'screens/sales_orders_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/supplier_bill_detail_screen.dart';
import 'screens/supplier_bill_form_screen.dart';
import 'screens/supplier_bills_screen.dart';
import 'screens/supplier_detail_screen.dart';
import 'screens/supplier_form_screen.dart';
import 'screens/supplier_payment_detail_screen.dart';
import 'screens/supplier_payment_form_screen.dart';
import 'screens/supplier_payments_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/transfer_stock_screen.dart';
import 'screens/trial_balance_screen.dart';
import 'screens/users_screen.dart';
import 'screens/warehouses_screen.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.value != null;
      final loc = state.uri.path;
      final isAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // ─────────────────────────────────────────────
      // AUTH (no shell)
      // ─────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, _) =>
            const NoTransitionPage(child: SignupScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, _) =>
            const NoTransitionPage(child: ForgotPasswordScreen()),
      ),

      // ─────────────────────────────────────────────
      // MAIN APP (with shell)
      // ─────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ── Dashboard ──
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),

          // ── Products ──
          GoRoute(
            path: '/products',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProductsScreen()),
          ),
          GoRoute(
            path: '/products/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProductFormScreen()),
          ),
          GoRoute(
            path: '/products/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: ProductDetailScreen(
                  productId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/products/:id/edit',
            pageBuilder: (_, state) => NoTransitionPage(
              child: ProductFormScreen(
                  productId: state.pathParameters['id']!),
            ),
          ),

          // ── Categories ──
          GoRoute(
            path: '/categories',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: CategoriesScreen()),
          ),

          // ── Warehouses ──
          GoRoute(
            path: '/warehouses',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: WarehousesScreen()),
          ),

          // ── Inventory ──
          GoRoute(
            path: '/inventory',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: InventoryScreen()),
          ),
          GoRoute(
            path: '/inventory/receive',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ReceiveStockScreen()),
          ),
          GoRoute(
            path: '/inventory/adjust',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: AdjustStockScreen()),
          ),
          GoRoute(
            path: '/inventory/transfer',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: TransferStockScreen()),
          ),
          GoRoute(
            path: '/inventory/product/:id',
            pageBuilder: (_, state) {
              final wh = state.uri.queryParameters['wh'];
              return NoTransitionPage(
                child: StockDetailScreen(
                  productId: state.pathParameters['id']!,
                  warehouseId: wh,
                ),
              );
            },
          ),

          // ── Suppliers ──
          GoRoute(
            path: '/suppliers',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SuppliersScreen()),
          ),
          GoRoute(
            path: '/suppliers/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SupplierFormScreen()),
          ),
          GoRoute(
            path: '/suppliers/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SupplierDetailScreen(
                  supplierId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/suppliers/:id/edit',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SupplierFormScreen(
                  supplierId: state.pathParameters['id']!),
            ),
          ),

          // ── Customers ──
          GoRoute(
            path: '/customers',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: CustomersScreen()),
          ),
          GoRoute(
            path: '/customers/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: CustomerFormScreen()),
          ),
          GoRoute(
            path: '/customers/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: CustomerDetailScreen(
                  customerId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/customers/:id/edit',
            pageBuilder: (_, state) => NoTransitionPage(
              child: CustomerFormScreen(
                  customerId: state.pathParameters['id']!),
            ),
          ),

          // ─────────────────────────────────────────────
          // PURCHASING
          // ─────────────────────────────────────────────
          GoRoute(
            path: '/purchasing',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PurchaseOrdersScreen()),
          ),
          GoRoute(
            path: '/purchasing/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PurchaseOrderFormScreen()),
          ),

          // GRN (specific)
          GoRoute(
            path: '/purchasing/receipts',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: GoodsReceiptsScreen()),
          ),
          GoRoute(
            path: '/purchasing/receipts/new',
            pageBuilder: (_, state) => NoTransitionPage(
              child: GoodsReceiptFormScreen(
                  poId: state.uri.queryParameters['po']),
            ),
          ),
          GoRoute(
            path: '/purchasing/receipts/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: GoodsReceiptDetailScreen(
                  grnId: state.pathParameters['id']!),
            ),
          ),

          // Supplier Bills (specific)
          GoRoute(
            path: '/purchasing/bills',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SupplierBillsScreen()),
          ),
          GoRoute(
            path: '/purchasing/bills/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SupplierBillFormScreen()),
          ),
          GoRoute(
            path: '/purchasing/bills/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SupplierBillDetailScreen(
                  billId: state.pathParameters['id']!),
            ),
          ),

          // Supplier Payments (specific)
          GoRoute(
            path: '/purchasing/payments',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SupplierPaymentsScreen()),
          ),
          GoRoute(
            path: '/purchasing/payments/new',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SupplierPaymentFormScreen(
                  billId: state.uri.queryParameters['bill']),
            ),
          ),
          GoRoute(
            path: '/purchasing/payments/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SupplierPaymentDetailScreen(
                  paymentId: state.pathParameters['id']!),
            ),
          ),

          // PO — generic :id (LAST in purchasing)
          GoRoute(
            path: '/purchasing/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: PurchaseOrderDetailScreen(
                  poId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/purchasing/:id/edit',
            pageBuilder: (_, state) => NoTransitionPage(
              child: PurchaseOrderFormScreen(
                  poId: state.pathParameters['id']!),
            ),
          ),

          // ─────────────────────────────────────────────
          // SALES
          // ─────────────────────────────────────────────
          GoRoute(
            path: '/sales',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SalesOrdersScreen()),
          ),
          GoRoute(
            path: '/sales/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SalesOrderFormScreen()),
          ),
          GoRoute(
            path: '/sales/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SalesOrderDetailScreen(
                  soId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/sales/:id/edit',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SalesOrderFormScreen(
                  soId: state.pathParameters['id']!),
            ),
          ),

          // ── Invoices ──
          GoRoute(
            path: '/invoices',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SalesInvoicesScreen()),
          ),
          GoRoute(
            path: '/invoices/new',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SalesInvoiceFormScreen(
                  salesOrderId: state.uri.queryParameters['so']),
            ),
          ),
          GoRoute(
            path: '/invoices/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: SalesInvoiceDetailScreen(
                  invoiceId: state.pathParameters['id']!),
            ),
          ),

          // ─────────────────────────────────────────────
          // ACCOUNTING
          // ─────────────────────────────────────────────
          GoRoute(
            path: '/accounting/coa',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ChartOfAccountsScreen()),
          ),
          GoRoute(
            path: '/accounting/journal',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: JournalEntriesScreen()),
          ),
          GoRoute(
            path: '/accounting/journal/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: JournalEntryFormScreen()),
          ),
          GoRoute(
            path: '/accounting/journal/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: JournalEntryDetailScreen(
                  entryId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/accounting/trial-balance',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: TrialBalanceScreen()),
          ),
          GoRoute(
            path: '/accounting/profit-loss',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ProfitLossScreen()),
          ),
          GoRoute(
            path: '/accounting/balance-sheet',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: BalanceSheetScreen()),
          ),

          // ─────────────────────────────────────────────
          // OTHER MODULES (hidden from sidebar, still reachable)
          // ─────────────────────────────────────────────
          GoRoute(
            path: '/currencies',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: CurrenciesScreen()),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ReportsScreen()),
          ),

          // ─────────────────────────────────────────────
          // ADMIN
          // ─────────────────────────────────────────────
          GoRoute(
            path: '/users',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: UsersScreen()),
          ),
          GoRoute(
            path: '/roles',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: RolesScreen()),
          ),
          GoRoute(
            path: '/roles/new',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: RoleFormScreen()),
          ),
          GoRoute(
            path: '/roles/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              child: RoleFormScreen(
                  roleId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}