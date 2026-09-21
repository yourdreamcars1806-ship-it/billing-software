import 'package:equatable/equatable.dart';

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.businessId,
    required this.todaySales,
    required this.todayCollection,
    required this.pendingAmount,
    required this.totalInvoices,
    required this.paidInvoices,
    required this.partialInvoices,
    required this.pendingInvoices,
  });

  final String businessId;
  final double todaySales;
  final double todayCollection;
  final double pendingAmount;
  final int totalInvoices;
  final int paidInvoices;
  final int partialInvoices;
  final int pendingInvoices;

  factory DashboardStats.empty(String businessId) => DashboardStats(
        businessId: businessId,
        todaySales: 0,
        todayCollection: 0,
        pendingAmount: 0,
        totalInvoices: 0,
        paidInvoices: 0,
        partialInvoices: 0,
        pendingInvoices: 0,
      );

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      businessId: json['business_id'] as String,
      todaySales: _toDouble(json['today_sales']),
      todayCollection: _toDouble(json['today_collection']),
      pendingAmount: _toDouble(json['pending_amount']),
      totalInvoices: json['total_invoices'] as int? ?? 0,
      paidInvoices: json['paid_invoices'] as int? ?? 0,
      partialInvoices: json['partial_invoices'] as int? ?? 0,
      pendingInvoices: json['pending_invoices'] as int? ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [
        businessId,
        todaySales,
        todayCollection,
        pendingAmount,
        totalInvoices,
      ];
}
