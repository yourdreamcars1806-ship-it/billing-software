import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/business.dart';
import '../../../models/invoice.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentAsync = ref.watch(recentInvoicesProvider);
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final partialLabel = business?.isCar == true ? 'Token' : 'Partial';

    return AppScaffold(
      title: 'Dashboard',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentInvoicesProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load desk: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate600),
              ),
            ),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              BrandBanner(
                title: business?.name ?? "Today's desk",
                subtitle: business?.isCar == true
                    ? 'Automobile billing · sales & collection'
                    : 'Clothing desk · scan, bill & collect',
                brand: brand,
                soft: AppColors.brandSoft(business?.businessType),
                icon: business?.isCar == true
                    ? Icons.directions_car_filled_rounded
                    : Icons.checkroom_rounded,
              ),
              const SizedBox(height: 16),
              DeskPrimaryButton(
                label: 'New invoice',
                icon: Icons.add_rounded,
                onPressed: () => context.go('/billing'),
              ),
              const SizedBox(height: 20),
              SectionLabel("Today's numbers"),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  StatCard(
                    title: "Today's Sales",
                    value: stats.todaySales,
                    icon: Icons.trending_up_rounded,
                    color: brand,
                    subtitle: 'Invoiced today',
                  ),
                  StatCard(
                    title: 'Collection',
                    value: stats.todayCollection,
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    subtitle: 'Received today',
                  ),
                  StatCard(
                    title: 'Pending',
                    value: stats.pendingAmount,
                    icon: Icons.hourglass_top_rounded,
                    color: AppColors.warning,
                    subtitle: 'Outstanding',
                  ),
                  StatCard(
                    title: 'Invoices',
                    value: stats.totalInvoices,
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                    isCurrency: false,
                    subtitle: '${stats.paidInvoices} paid',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SoftSurface(
                elevated: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    _StatusPill(
                      label: 'Paid',
                      value: stats.paidInvoices,
                      color: AppColors.success,
                    ),
                    _StatusPill(
                      label: partialLabel,
                      value: stats.partialInvoices,
                      color: AppColors.warning,
                    ),
                    _StatusPill(
                      label: 'Pending',
                      value: stats.pendingInvoices,
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionLabel(
                'Recent invoices',
                action: TextButton(
                  onPressed: () => context.go('/invoices'),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              recentAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load invoices',
                ),
                data: (invoices) {
                  if (invoices.isEmpty) {
                    return SoftSurface(
                      elevated: true,
                      child: const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'No invoices yet',
                        message: 'Create your first bill from Billing',
                      ),
                    );
                  }
                  return Column(
                    children: invoices
                        .map(
                          (invoice) => _RecentInvoiceTile(
                            invoice: invoice,
                            businessType: business?.businessType,
                            brand: brand,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentInvoiceTile extends StatelessWidget {
  const _RecentInvoiceTile({
    required this.invoice,
    required this.brand,
    this.businessType,
  });

  final Invoice invoice;
  final Color brand;
  final BusinessType? businessType;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (invoice.paymentStatus) {
      PaymentStatus.paid => AppColors.success,
      PaymentStatus.partial => AppColors.warning,
      PaymentStatus.pending => AppColors.error,
    };
    final label = paymentStatusLabel(
      invoice.paymentStatus.name,
      businessType: businessType,
    );

    return SoftSurface(
      elevated: true,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: () => context.push('/invoices/${invoice.id}'),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: brand,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppDateUtils.formatDate(invoice.invoiceDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyUtils.format(invoice.grandTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusBadge(label: label, color: statusColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
