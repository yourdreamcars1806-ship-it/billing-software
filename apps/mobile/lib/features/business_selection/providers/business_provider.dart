import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/business.dart';
import '../../../repositories/business_repository.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../invoices/providers/invoices_provider.dart';

final activeBusinessProvider = NotifierProvider<ActiveBusinessNotifier, Business?>(
  ActiveBusinessNotifier.new,
);

class ActiveBusinessNotifier extends Notifier<Business?> {
  @override
  Business? build() => null;

  Future<void> loadSavedBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(AppConstants.activeBusinessIdKey);
    if (savedId == null) return;

    final business = await ref.read(businessRepositoryProvider).getBusinessById(savedId);
    if (business != null) {
      state = business;
    }
  }

  Future<void> setActiveBusiness(Business business) async {
    state = business;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.activeBusinessIdKey, business.id);
    _invalidateBusinessScopedProviders();
  }

  void clearBusiness() {
    state = null;
  }

  void _invalidateBusinessScopedProviders() {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(recentInvoicesProvider);
    ref.invalidate(invoicesProvider);
  }
}

final businessSelectionProvider = FutureProvider<List<Business>>((ref) async {
  return ref.watch(businessRepositoryProvider).getUserBusinesses();
});
