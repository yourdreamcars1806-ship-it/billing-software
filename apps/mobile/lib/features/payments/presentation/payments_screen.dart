import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_utils.dart';
import '../../../models/payment.dart';
import '../../../repositories/payment_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';

final paymentsHistoryProvider =
    FutureProvider.autoDispose<List<PaymentWithInvoice>>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return [];
  return ref.read(paymentRepositoryProvider).getPaymentsHistory(business.id);
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final async = ref.watch(paymentsHistoryProvider);
    final money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');

    return AppScaffold(
      title: 'Payments',
      showBusinessSwitcher: false,
      fallbackRoute: '/more',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              DeskHeader(
                title: 'Payments',
                subtitle: 'Collection history',
                trailing: IconBadge(
                  icon: Icons.payments_outlined,
                  color: brand,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                SoftSurface(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 44,
                        color: AppColors.slate300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No payments yet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                )
              else
                ...rows.map((row) {
                  return SoftSurface(
                    margin: const EdgeInsets.only(bottom: 8),
                    onTap: () => context.push('/invoices/${row.invoiceId}'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.invoiceNumber ?? 'Invoice',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${AppDateUtils.formatDate(row.payment.paymentDate)} · ${Payment.label(row.payment.paymentMethod)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money.format(row.payment.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: brand,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
