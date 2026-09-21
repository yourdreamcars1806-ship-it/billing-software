import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/invoice.dart';
import '../../../repositories/invoice_repository.dart';
import '../../business_selection/providers/business_provider.dart';

final invoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return [];

  return ref.read(invoiceRepositoryProvider).getInvoices(business.id, limit: 100);
});

final invoiceProvider = FutureProvider.family<Invoice?, String>((ref, invoiceId) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return null;

  return ref.read(invoiceRepositoryProvider).getInvoice(business.id, invoiceId);
});
