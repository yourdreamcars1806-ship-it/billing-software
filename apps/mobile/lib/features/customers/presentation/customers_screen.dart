import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../providers/customers_provider.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);

    return AppScaffold(
      title: 'Customers',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customersProvider),
        child: customersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (customers) {
            if (customers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const DeskHeader(
                    title: 'Customers',
                    subtitle: 'Contacts for billing & WhatsApp',
                  ),
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers yet',
                    message:
                        'Type a customer name while creating a bill',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: customers.length + 1,
              separatorBuilder: (_, index) =>
                  SizedBox(height: index == 0 ? 12 : 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return DeskHeader(
                    title: 'Customers',
                    subtitle: '${customers.length} contacts',
                  );
                }

                final customer = customers[index - 1];
                return SoftSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  onTap: () => context.push('/customers/${customer.id}'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: brand.withValues(alpha: 0.12),
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              customer.mobile ??
                                  customer.email ??
                                  'No contact info',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.slate300,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
