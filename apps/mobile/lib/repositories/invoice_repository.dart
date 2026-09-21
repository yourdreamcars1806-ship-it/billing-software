import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/dashboard_stats.dart';
import '../models/invoice.dart';
import '../services/supabase_service.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(supabaseServiceProvider));
});

class InvoiceRepository {
  InvoiceRepository(this._supabase);

  final SupabaseService _supabase;

  Future<List<Invoice>> getInvoices(String businessId, {int limit = 100}) async {
    try {
      // Same query shape as web invoices-manager
      final response = await _supabase.client
          .from(AppConstants.tableInvoices)
          .select('*, customers(name, mobile, email, address)')
          .eq('business_id', businessId)
          .eq('status', 'issued')
          .order('invoice_date', ascending: false)
          .limit(limit);

      final list = <Invoice>[];
      for (final row in response as List<dynamic>) {
        try {
          list.add(
            Invoice.fromJson(Map<String, dynamic>.from(row as Map)),
          );
        } catch (_) {
          // Skip malformed row rather than failing the whole list
        }
      }
      return list;
    } catch (e) {
      // Fallback without embed if relationship query fails
      try {
        final response = await _supabase.client
            .from(AppConstants.tableInvoices)
            .select()
            .eq('business_id', businessId)
            .eq('status', 'issued')
            .order('invoice_date', ascending: false)
            .limit(limit);
        return (response as List<dynamic>)
            .map((row) => Invoice.fromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
      } catch (e2) {
        throw NetworkException('Failed to load invoices: $e2');
      }
    }
  }

  Future<Invoice?> getInvoice(String businessId, String invoiceId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableInvoices)
          .select(
            '*, invoice_items(*), payments(*), customers(*)',
          )
          .eq('business_id', businessId)
          .eq('id', invoiceId)
          .maybeSingle();

      if (response == null) return null;
      return Invoice.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw NetworkException('Failed to load invoice: $e');
    }
  }

  Future<List<Invoice>> getRecentInvoices(String businessId, {int limit = 5}) async {
    return getInvoices(businessId, limit: limit);
  }

  Future<Invoice> createInvoice(Invoice invoice) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableInvoices)
          .insert(invoice.toJson())
          .select()
          .single();

      return Invoice.fromJson(response);
    } catch (e) {
      throw NetworkException('Failed to create invoice: $e');
    }
  }

  Future<void> deleteInvoice(String businessId, String invoiceId) async {
    try {
      await _supabase.client
          .from(AppConstants.tableInvoices)
          .update({'status': 'cancelled'})
          .eq('business_id', businessId)
          .eq('id', invoiceId);
    } catch (e) {
      throw NetworkException('Failed to delete invoice: $e');
    }
  }

  Future<DashboardStats> getDashboardStats(String businessId) async {
    try {
      // Use SQL view — one round-trip instead of downloading every invoice.
      final row = await _supabase.client
          .from('dashboard_stats')
          .select()
          .eq('business_id', businessId)
          .maybeSingle();

      if (row != null) {
        return DashboardStats(
          businessId: businessId,
          todaySales: _toDouble(row['today_sales']),
          todayCollection: _toDouble(row['today_collection']),
          pendingAmount: _toDouble(row['pending_amount']),
          totalInvoices: (row['total_invoices'] as num?)?.toInt() ?? 0,
          paidInvoices: (row['paid_invoices'] as num?)?.toInt() ?? 0,
          partialInvoices: (row['partial_invoices'] as num?)?.toInt() ?? 0,
          pendingInvoices: (row['pending_invoices'] as num?)?.toInt() ?? 0,
        );
      }

      return DashboardStats.empty(businessId);
    } catch (e) {
      return DashboardStats.empty(businessId);
    }
  }

  Future<MonthReportStats> getMonthReportStats(String businessId) async {
    final today = DateTime.now();
    final monthStart =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-01';

    final monthInvoices = await _supabase.client
        .from(AppConstants.tableInvoices)
        .select('grand_total, payment_status, amount_outstanding')
        .eq('business_id', businessId)
        .eq('status', 'issued')
        .gte('invoice_date', monthStart);

    final monthPayments = await _supabase.client
        .from(AppConstants.tablePayments)
        .select('amount, payment_method')
        .eq('business_id', businessId)
        .gte('payment_date', monthStart);

    var monthlySales = 0.0;
    var outstanding = 0.0;
    var paid = 0;
    var partial = 0;
    var pending = 0;
    for (final row in monthInvoices as List) {
      final map = Map<String, dynamic>.from(row as Map);
      monthlySales += _toDouble(map['grand_total']);
      outstanding += _toDouble(map['amount_outstanding']);
      switch (map['payment_status'] as String?) {
        case 'paid':
          paid++;
        case 'partial':
          partial++;
        default:
          pending++;
      }
    }

    var monthlyCollection = 0.0;
    final methodMap = <String, double>{};
    for (final row in monthPayments as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final amt = _toDouble(map['amount']);
      monthlyCollection += amt;
      final method = (map['payment_method'] as String?) ?? 'other';
      methodMap[method] = (methodMap[method] ?? 0) + amt;
    }

    return MonthReportStats(
      monthlySales: monthlySales,
      monthlyCollection: monthlyCollection,
      outstanding: outstanding,
      paid: paid,
      partial: partial,
      pending: pending,
      methods: methodMap.entries
          .map((e) => MethodAmount(method: e.key, amount: e.value))
          .toList(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class MethodAmount {
  const MethodAmount({required this.method, required this.amount});
  final String method;
  final double amount;
}

class MonthReportStats {
  const MonthReportStats({
    required this.monthlySales,
    required this.monthlyCollection,
    required this.outstanding,
    required this.paid,
    required this.partial,
    required this.pending,
    required this.methods,
  });

  final double monthlySales;
  final double monthlyCollection;
  final double outstanding;
  final int paid;
  final int partial;
  final int pending;
  final List<MethodAmount> methods;

  factory MonthReportStats.empty() => const MonthReportStats(
        monthlySales: 0,
        monthlyCollection: 0,
        outstanding: 0,
        paid: 0,
        partial: 0,
        pending: 0,
        methods: [],
      );
}
