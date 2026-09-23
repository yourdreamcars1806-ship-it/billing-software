import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, upi, upiCash, card, bankTransfer, other }

class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.businessId,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
  });

  final String id;
  final String businessId;
  final String invoiceId;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['payment_date'] ?? json['created_at'];
    DateTime paymentDate;
    if (dateRaw is String && dateRaw.isNotEmpty) {
      paymentDate = DateTime.tryParse(dateRaw) ?? DateTime.now();
    } else {
      paymentDate = DateTime.now();
    }
    return Payment(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      invoiceId: json['invoice_id'] as String,
      amount: _toDouble(json['amount']),
      paymentDate: paymentDate,
      paymentMethod: _parsePaymentMethod(json['payment_method'] as String?),
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String().split('T').first,
        'payment_method': _paymentMethodToString(paymentMethod),
        'reference_number': referenceNumber,
        'notes': notes,
      };

  static PaymentMethod _parsePaymentMethod(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'upi':
        return PaymentMethod.upi;
      case 'upi_cash':
        return PaymentMethod.upiCash;
      case 'card':
        return PaymentMethod.card;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'other':
      default:
        return PaymentMethod.other;
    }
  }

  static String _paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.upiCash:
        return 'upi_cash';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.other:
        return 'other';
    }
  }

  static String label(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.upiCash:
        return 'UPI + Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  /// DB / API string for create-invoice.
  static String toApi(PaymentMethod method) => _paymentMethodToString(method);

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [id, businessId, invoiceId, amount, paymentDate];
}
