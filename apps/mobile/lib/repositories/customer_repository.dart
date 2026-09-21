import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/customer.dart';
import '../services/supabase_service.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(supabaseServiceProvider));
});

class CustomerRepository {
  CustomerRepository(this._supabase);

  final SupabaseService _supabase;

  Future<List<Customer>> getCustomers(String businessId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableCustomers)
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      return (response as List<dynamic>)
          .map((row) => Customer.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw NetworkException('Failed to load customers: $e');
    }
  }

  Future<Customer?> getCustomer(String businessId, String customerId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableCustomers)
          .select()
          .eq('business_id', businessId)
          .eq('id', customerId)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to load customer: $e');
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final data = customer.toJson();
      data.remove('id');

      final response = await _supabase.client
          .from(AppConstants.tableCustomers)
          .insert(data)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to create customer: $e');
    }
  }

  Future<Customer> updateCustomer(Customer customer) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableCustomers)
          .update(customer.toJson())
          .eq('business_id', customer.businessId)
          .eq('id', customer.id)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to update customer: $e');
    }
  }

  Future<void> deleteCustomer(String businessId, String customerId) async {
    try {
      await _supabase.client
          .from(AppConstants.tableCustomers)
          .update({'is_active': false})
          .eq('business_id', businessId)
          .eq('id', customerId);
    } catch (e) {
      throw NetworkException('Failed to delete customer: $e');
    }
  }
}
