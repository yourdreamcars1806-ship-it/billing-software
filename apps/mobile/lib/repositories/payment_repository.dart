import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/payment.dart';
import '../services/supabase_service.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseServiceProvider));
});

class PaymentWithInvoice {
  const PaymentWithInvoice({
    required this.payment,
    required this.invoiceId,
    this.invoiceNumber,
  });

  final Payment payment;
  final String invoiceId;
  final String? invoiceNumber;
}

class PaymentRepository {
  PaymentRepository(this._supabase);

  final SupabaseService _supabase;

  Future<List<Payment>> getPaymentsForInvoice(
    String businessId,
    String invoiceId,
  ) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tablePayments)
          .select()
          .eq('business_id', businessId)
          .eq('invoice_id', invoiceId)
          .order('payment_date', ascending: false);

      return (response as List<dynamic>)
          .map((row) => Payment.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw NetworkException('Failed to load payments: $e');
    }
  }

  Future<List<PaymentWithInvoice>> getPaymentsHistory(
    String businessId, {
    int limit = 80,
  }) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tablePayments)
          .select('*, invoices(invoice_number)')
          .eq('business_id', businessId)
          .order('payment_date', ascending: false)
          .limit(limit);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final inv = map['invoices'];
        String? number;
        if (inv is Map) {
          number = inv['invoice_number'] as String?;
        }
        return PaymentWithInvoice(
          payment: Payment.fromJson(map),
          invoiceId: map['invoice_id'] as String,
          invoiceNumber: number,
        );
      }).toList();
    } catch (e) {
      throw NetworkException('Failed to load payment history: $e');
    }
  }

  Future<Payment> addPayment(Payment payment) async {
    try {
      final data = payment.toJson();
      data.remove('id');

      final response = await _supabase.client
          .from(AppConstants.tablePayments)
          .insert(data)
          .select()
          .single();

      return Payment.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to add payment: $e');
    }
  }
}
