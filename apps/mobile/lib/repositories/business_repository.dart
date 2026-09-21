import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/businesses.dart';
import '../core/constants/app_constants.dart';
import '../models/business.dart';
import '../services/supabase_service.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseServiceProvider));
});

class BusinessRepository {
  BusinessRepository(this._supabase);

  final SupabaseService _supabase;

  Future<List<Business>> getUserBusinesses() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase.client
          .from(AppConstants.tableBusinessUsers)
          .select('business_id, businesses(*)')
          .eq('user_id', userId)
          .eq('is_active', true);

      final rows = response as List<dynamic>;
      if (rows.isEmpty) {
        return BusinessConfig.all.where((b) => b.isActive).toList();
      }

      final businesses = <Business>[];
      for (final row in rows) {
        final businessData = row['businesses'];
        if (businessData != null) {
          businesses.add(Business.fromJson(businessData as Map<String, dynamic>));
        } else {
          final id = row['business_id'] as String?;
          final fallback = id != null ? BusinessConfig.findById(id) : null;
          if (fallback != null) businesses.add(fallback);
        }
      }
      return businesses;
    } catch (_) {
      return BusinessConfig.all.where((b) => b.isActive).toList();
    }
  }

  Future<Business?> getBusinessById(String businessId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableBusinesses)
          .select()
          .eq('id', businessId)
          .maybeSingle();

      if (response != null) {
        return Business.fromJson(response);
      }
    } catch (_) {}

    return BusinessConfig.findById(businessId);
  }
}
