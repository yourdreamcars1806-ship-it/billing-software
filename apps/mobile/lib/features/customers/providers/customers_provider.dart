import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/customer.dart';
import '../../../repositories/customer_repository.dart';
import '../../business_selection/providers/business_provider.dart';

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return [];

  return ref.read(customerRepositoryProvider).getCustomers(business.id);
});

final customerProvider = FutureProvider.family<Customer?, String>((ref, customerId) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return null;

  return ref.read(customerRepositoryProvider).getCustomer(business.id, customerId);
});
