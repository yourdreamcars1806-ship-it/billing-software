import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../repositories/invoice_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';

final monthReportsProvider =
    FutureProvider.autoDispose<MonthReportStats>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) {
    return MonthReportStats.empty();
  }
  return ref.read(invoiceRepositoryProvider).getMonthReportStats(business.id);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final async = ref.watch(monthReportsProvider);
    final isCar = business?.isCar == true;

    return AppScaffold(
      title: 'Reports',
      showBusinessSwitcher: false,
      fallbackRoute: '/more',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              DeskHeader(
                title: 'Month summary',
                subtitle: isCar
                    ? 'Automobile desk · sales & collection'
                    : 'Clothing desk · sales & collection',
              ),
              const SizedBox(height: 14),
              SoftSurface(
                child: _StatRow(
                  label: 'Monthly sales',
                  value: CurrencyUtils.format(stats.monthlySales),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: 8),
              SoftSurface(
                child: _StatRow(
                  label: 'Monthly collection',
                  value: CurrencyUtils.format(stats.monthlyCollection),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              SoftSurface(
                child: _StatRow(
                  label: 'Outstanding',
                  value: CurrencyUtils.format(stats.outstanding),
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 14),
              SoftSurface(
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Paid invoices',
                      value: '${stats.paid}',
                    ),
                    _StatRow(
                      label: isCar ? 'Token invoices' : 'Partial invoices',
                      value: '${stats.partial}',
                    ),
                    _StatRow(
                      label: 'Pending invoices',
                      value: '${stats.pending}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Collection by method'),
              const SizedBox(height: 10),
              SoftSurface(
                child: stats.methods.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No payments recorded this month',
                            style: TextStyle(color: AppColors.slate500),
                          ),
                        ),
                      )
                    : Column(
                        children: stats.methods.map((m) {
                          return _StatRow(
                            label: m.method.replaceAll('_', ' '),
                            value: CurrencyUtils.format(m.amount),
                            color: brand,
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.slate900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
