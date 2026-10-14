import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/purchase_order.dart';
import '../providers/inventory_provider.dart';
import '../providers/purchase_order_provider.dart';
import '../providers/settings_provider.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/inventory_widgets.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

// ─────────────────────────────────────────────────────────
// SUMMARY PROVIDER — Real aggregations from Firestore
// ─────────────────────────────────────────────────────────
class DashboardSummary {
  final num totalSales;
  final num totalPurchases;
  final num receivables;
  final num payables;
  final num grossProfit;
  final num inventoryValue;
  final int lowStockCount;
  final List<Map<String, dynamic>> recentSales;
  final List<Map<String, dynamic>> recentPurchases;
  final List<StockBalance> lowStockItems;

  DashboardSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.receivables,
    required this.payables,
    required this.grossProfit,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.recentSales,
    required this.recentPurchases,
    required this.lowStockItems,
  });
}

final _dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = FirebaseFirestore.instance;

  // ─── Total Sales (sum of posted invoices grandTotal * exchangeRate)
  num sumField(List<QueryDocumentSnapshot> docs, String field) {
    return docs.fold<num>(
      0,
      (acc, d) => acc + ((d.data() as Map)[field] as num? ?? 0),
    );
  }

  num totalSales = 0;
  num receivables = 0;
  num cogs = 0;
  List<Map<String, dynamic>> recentSales = [];

  try {
    final invSnap = await db
        .collection('salesInvoices')
        .where('status', isEqualTo: 'posted')
        .orderBy('createdAt', descending: true)
        .get();
    totalSales = invSnap.docs.fold<num>(0, (acc, d) {
      final m = d.data();
      final gt = (m['grandTotal'] ?? 0) as num;
      final rate = (m['exchangeRate'] ?? 1) as num;
      return acc + (gt * rate);
    });
    receivables = invSnap.docs.fold<num>(0, (acc, d) {
      final m = d.data();
      final out = (m['grandTotal'] ?? 0) as num; -
          (m['amountPaid'] ?? 0) as num;
      final rate = (m['exchangeRate'] ?? 1) as num;
      return acc + (out * rate);
    });
    cogs = invSnap.docs.fold<num>(0, (acc, d) {
      final m = d.data();
      final lines = (m['lines'] as List<dynamic>? ?? []);
      num cost = 0;
      for (final l in lines) {
        final line = l as Map<String, dynamic>;
        cost += ((line['quantity'] ?? 0) as num) *
            ((line['unitCost'] ?? 0) as num);
      }
      final rate = (m['exchangeRate'] ?? 1) as num;
      return acc + (cost * rate);
    });
    recentSales = invSnap.docs.take(5).map((d) {
      final m = d.data();
      return {
        'number': m['number'] ?? '',
        'name': m['customerName'] ?? '',
        'total': ((m['grandTotal'] ?? 0) as num) *
            ((m['exchangeRate'] ?? 1) as num),
        'currency': m['currency'] ?? 'PKR',
      };
    }).toList();
  } catch (_) {}

  // ─── Total Purchases (approved + received POs)
  num totalPurchases = 0;
  num payables = 0;
  List<Map<String, dynamic>> recentPurchases = [];
  try {
    final poSnap = await db
        .collection('purchaseOrders')
        .orderBy('createdAt', descending: true)
        .get();
    totalPurchases = poSnap.docs
        .where((d) {
          final s = (d.data() as Map)['status'] as String? ?? '';
          return s == 'approved' ||
              s == 'received' ||
              s == 'partiallyReceived';
        })
        .fold<num>(0, (acc, d) {
      final m = d.data() as Map<String, dynamic>;
      final gt = (m['grandTotal'] ?? 0) as num;
      final rate = (m['exchangeRate'] ?? 1) as num;
      return acc + (gt * rate);
    });
    // Payables = approved but not fully paid (simplified — full workflow in Phase 7C)
    payables = totalPurchases;
    recentPurchases = poSnap.docs.take(5).map((d) {
      final m = d.data() as Map<String, dynamic>;
      return {
        'number': m['number'] ?? '',
        'name': m['supplierName'] ?? '',
        'total': ((m['grandTotal'] ?? 0) as num) *
            ((m['exchangeRate'] ?? 1) as num),
        'currency': m['currency'] ?? 'PKR',
        'status': m['status'] ?? '',
      };
    }).toList();
  } catch (_) {}

  // ─── Inventory Value + Low Stock
  num inventoryValue = 0;
  List<StockBalance> lowStockItems = [];
  try {
    final balSnap = await db.collection('stockBalances').get();
    inventoryValue = balSnap.docs.fold<num>(
      0,
      (acc, d) =>
          acc + ((d.data() as Map)['totalValue'] as num? ?? 0),
    );
    lowStockItems = balSnap.docs
        .map(StockBalance.fromDoc)
        .where((b) => b.isLowStock)
        .toList();
  } catch (_) {}

  final grossProfit = totalSales - cogs;

  return DashboardSummary(
    totalSales: totalSales,
    totalPurchases: totalPurchases,
    receivables: receivables,
    payables: payables,
    grossProfit: grossProfit,
    inventoryValue: inventoryValue,
    lowStockCount: lowStockItems.length,
    recentSales: recentSales,
    recentPurchases: recentPurchases,
    lowStockItems: lowStockItems.take(5).toList(),
  );
});

// ─────────────────────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_dashboardProvider);
    final settings = ref.watch(companySettingsProvider);
    final currency = settings.value?.baseCurrency ?? 'PKR';
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Executive Dashboard', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Live overview of Ahmed Chemical Co. operations',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 24),

          summary.when(
            loading: () => const _LoadingGrid(),
            error: (e, _) => SectionCard(
              title: 'Error',
              child: Text('Failed to load: $e',
                  style: AppTextStyles.bodySmall),
            ),
            data: (data) {
              String fmt(num v) => _fmt(v, currency);

              return Column(
                children: [
                  // ── Stat Grid ──
                  GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.6,
                    children: [
                      StatCard(
                        label: 'Total Sales',
                        value: fmt(data.totalSales),
                        icon: LucideIcons.trendingUp,
                      ),
                      StatCard(
                        label: 'Total Purchases',
                        value: fmt(data.totalPurchases),
                        icon: LucideIcons.shoppingCart,
                      ),
                      StatCard(
                        label: 'Gross Profit',
                        value: fmt(data.grossProfit),
                        icon: LucideIcons.wallet,
                      ),
                      StatCard(
                        label: 'Inventory Value',
                        value: fmt(data.inventoryValue),
                        icon: LucideIcons.package,
                      ),
                      StatCard(
                        label: 'Receivables',
                        value: fmt(data.receivables),
                        icon: LucideIcons.arrowDownToLine,
                      ),
                      StatCard(
                        label: 'Payables',
                        value: fmt(data.payables),
                        icon: LucideIcons.arrowUpFromLine,
                      ),
                      StatCard(
                        label: 'Low Stock Items',
                        value: '${data.lowStockCount}',
                        icon: LucideIcons.alertTriangle,
                      ),
                      StatCard(
                        label: 'Base Currency',
                        value: currency,
                        icon: LucideIcons.coins,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Chart Placeholder ──
                  SectionCard(
                    title: 'Monthly Sales & Purchases',
                    subtitle: 'Charts coming in a later update',
                    child: SizedBox(
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.barChart3,
                                size: 36, color: AppColors.textDim),
                            const SizedBox(height: 12),
                            Text(
                              data.totalSales == 0 &&
                                      data.totalPurchases == 0
                                  ? 'No transactions yet'
                                  : 'Chart not yet available',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create invoices and POs to see trends',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Recent Activity + Low Stock ──
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RecentActivityCard(
                            sales: data.recentSales,
                            purchases: data.recentPurchases,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _LowStockCard(
                            items: data.lowStockItems,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _RecentActivityCard(
                          sales: data.recentSales,
                          purchases: data.recentPurchases,
                        ),
                        const SizedBox(height: 20),
                        _LowStockCard(items: data.lowStockItems),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(num v, String currency) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$currency $s';
  }
}

// ─────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: List.generate(
        8,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> purchases;

  const _RecentActivityCard({
    required this.sales,
    required this.purchases,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Activity',
      trailing: TextButton(
        onPressed: () => context.go('/invoices'),
        child: const Text('View All'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent sales
          Text('Recent Sales', style: AppTextStyles.label),
          const SizedBox(height: 8),
          if (sales.isEmpty)
            _emptyLine('No sales yet')
          else
            ...sales.map((s) => _activityRow(
                  icon: LucideIcons.trendingUp,
                  color: AppColors.primary,
                  title: s['number'] as String,
                  subtitle: s['name'] as String,
                  amount: _fmt(
                    s['total'] as num,
                    s['currency'] as String,
                  ),
                  onTap: () => context.go('/invoices'),
                )),
          const SizedBox(height: 16),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Recent purchases
          Text('Recent Purchases', style: AppTextStyles.label),
          const SizedBox(height: 8),
          if (purchases.isEmpty)
            _emptyLine('No purchases yet')
          else
            ...purchases.map((p) => _activityRow(
                  icon: LucideIcons.shoppingCart,
                  color: AppColors.info,
                  title: p['number'] as String,
                  subtitle: p['name'] as String,
                  amount: _fmt(
                    p['total'] as num,
                    p['currency'] as String,
                  ),
                  onTap: () => context.go('/purchasing'),
                )),
        ],
      ),
    );
  }

  Widget _emptyLine(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(msg,
          style: AppTextStyles.caption.copyWith(color: AppColors.textDim)),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Text(amount,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }

  String _fmt(num v, String currency) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$currency $s';
  }
}

class _LowStockCard extends StatelessWidget {
  final List<StockBalance> items;

  const _LowStockCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Low Stock Alerts',
      trailing: TextButton(
        onPressed: () => context.go('/inventory'),
        child: const Text('View Inventory'),
      ),
      child: items.isEmpty
          ? SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.checkCircle,
                        size: 30, color: AppColors.primary),
                    const SizedBox(height: 10),
                    Text('No low stock items',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            )
          : Column(
              children: items.map((b) {
                return InkWell(
                  onTap: () => context.go(
                      '/inventory/product/${b.productId}?wh=${b.warehouseId}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.alertTriangle,
                              size: 15, color: AppColors.error),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.productName,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${b.sku} • ${b.warehouseName}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${b.quantity.toStringAsFixed(2)} ${b.baseUnit}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              'reorder at ${b.reorderLevel.toStringAsFixed(0)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}