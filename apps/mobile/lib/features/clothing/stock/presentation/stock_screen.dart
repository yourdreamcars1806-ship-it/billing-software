import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/clothing_categories.dart';
import '../../../../services/stock_service.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../theme/app_colors.dart';
import '../../../business_selection/providers/business_provider.dart';

final stockOverviewProvider =
    FutureProvider.autoDispose<StockOverview>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null || !business.isClothing) {
    return const StockOverview(
      totals: CategoryStockRow(
        category: 'Total',
        inStockPcs: 0,
        inStockItems: 0,
        outOfStockItems: 0,
        buyValue: 0,
        sellValue: 0,
        soldPcs: 0,
        soldValue: 0,
      ),
      categories: [],
    );
  }
  return ref.read(stockServiceProvider).loadStockOverview(business.id);
});

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final async = ref.watch(stockOverviewProvider);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    if (business != null && !business.isClothing) {
      return const AppScaffold(
        title: 'Stock',
        showBusinessSwitcher: false,
        body: Center(child: Text('Stock is for clothing desk only')),
      );
    }

    return AppScaffold(
      title: 'Stock',
      showBusinessSwitcher: false,
      fallbackRoute: '/more',
      actions: [
        IconButton(
          tooltip: 'Products',
          onPressed: () => context.push('/products'),
          icon: Icon(Icons.qr_code_2_rounded, color: brand),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(stockOverviewProvider),
          icon: Icon(Icons.refresh_rounded, color: brand),
        ),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(stockOverviewProvider),
        ),
        data: (overview) {
          final byName = {
            for (final c in overview.categories) c.category: c,
          };
          final rows = <CategoryStockRow>[
            for (final cat in clothingCategories)
              byName[cat] ??
                  CategoryStockRow(
                    category: cat,
                    inStockPcs: 0,
                    inStockItems: 0,
                    outOfStockItems: 0,
                    buyValue: 0,
                    sellValue: 0,
                    soldPcs: 0,
                    soldValue: 0,
                  ),
            for (final c in overview.categories)
              if (!clothingCategories.contains(c.category)) c,
          ];
          final t = overview.totals;

          return RefreshIndicator(
            color: brand,
            onRefresh: () async {
              ref.invalidate(stockOverviewProvider);
              await ref.read(stockOverviewProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock by category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDark(business?.businessType),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Har category · stock · buy · sell',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _TotalsStrip(
                          brand: brand,
                          soft: soft,
                          inStock: t.inStockPcs,
                          noStock: t.outOfStockItems,
                          buy: money.format(t.buyValue),
                          sell: money.format(t.sellValue),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CATEGORIES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.slate400,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 136,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _CategoryCard(
                        row: rows[i],
                        brand: brand,
                        soft: soft,
                        money: money,
                      ),
                      childCount: rows.length,
                    ),
                  ),
                ),
                if (t.soldPcs > 0)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Sold · ${t.soldPcs.toStringAsFixed(0)} pcs · ${money.format(t.soldValue)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({
    required this.brand,
    required this.soft,
    required this.inStock,
    required this.noStock,
    required this.buy,
    required this.sell,
  });

  final Color brand;
  final Color soft;
  final double inStock;
  final int noStock;
  final String buy;
  final String sell;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TotalCell(
                  label: 'In stock',
                  value: inStock.toStringAsFixed(0),
                  valueColor: AppColors.success,
                ),
              ),
              Container(width: 1, height: 52, color: AppColors.slate100),
              Expanded(
                child: _TotalCell(
                  label: 'No stock',
                  value: '$noStock',
                  valueColor:
                      noStock > 0 ? AppColors.error : AppColors.slate700,
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.slate100),
          Row(
            children: [
              Expanded(
                child: _TotalCell(
                  label: 'Buy value',
                  value: buy,
                  valueColor: AppColors.slate800,
                ),
              ),
              Container(width: 1, height: 52, color: AppColors.slate100),
              Expanded(
                child: _TotalCell(
                  label: 'Sell value',
                  value: sell,
                  valueColor: brand,
                  highlight: soft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.highlight,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.slate400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.row,
    required this.brand,
    required this.soft,
    required this.money,
  });

  final CategoryStockRow row;
  final Color brand;
  final Color soft;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final hasStock = row.inStockPcs > 0;
    final footer = [
      if (row.soldPcs > 0) 'Sold ${row.soldPcs.toStringAsFixed(0)}',
      if (row.outOfStockItems > 0) '${row.outOfStockItems} out',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: hasStock
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${row.inStockPcs.toStringAsFixed(0)} pcs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasStock ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PriceBox(
                  label: 'Buy',
                  value: money.format(row.buyValue),
                  bg: AppColors.slate50,
                  fg: AppColors.slate800,
                  labelColor: AppColors.slate500,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PriceBox(
                  label: 'Sell',
                  value: money.format(row.sellValue),
                  bg: soft,
                  fg: brand,
                  labelColor: brand,
                ),
              ),
            ],
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.slate400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: labelColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
