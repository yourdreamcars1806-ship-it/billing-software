import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/dashboard_stats.dart';
import '../../../models/invoice.dart';
import '../../../repositories/invoice_repository.dart';
import '../../business_selection/providers/business_provider.dart';

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) {
    throw StateError('No active business selected');
  }

  return ref.read(invoiceRepositoryProvider).getDashboardStats(business.id);
});

final recentInvoicesProvider = FutureProvider<List<Invoice>>((ref) async {
  final business = ref.watch(activeBusinessProvider);
  if (business == null) return [];

  return ref.read(invoiceRepositoryProvider).getRecentInvoices(business.id, limit: 5);
});
