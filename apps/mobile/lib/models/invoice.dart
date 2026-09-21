import 'package:equatable/equatable.dart';

import 'customer.dart';
import 'payment.dart';

enum InvoiceStatus { draft, issued, cancelled }

enum PaymentStatus { paid, partial, pending }

class InvoiceItem extends Equatable {
  const InvoiceItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.taxRate = 0,
    this.size,
    this.color,
    this.barcode,
    this.productVariantId,
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double taxRate;
  final String? size;
  final String? color;
  final String? barcode;
  final String? productVariantId;

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: Invoice._toDouble(json['quantity']),
      unitPrice: Invoice._toDouble(json['unit_price']),
      lineTotal: Invoice._toDouble(json['line_total']),
      taxRate: Invoice._toDouble(json['tax_rate']),
      size: json['size'] as String?,
      color: json['color'] as String?,
      barcode: json['barcode'] as String?,
      productVariantId: json['product_variant_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, description, quantity, lineTotal];
}

class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.businessId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.additionalCharges,
    required this.grandTotal,
    required this.amountPaid,
    required this.amountOutstanding,
    this.customerId,
    this.notes,
    this.carMake,
    this.carModel,
    this.carVariant,
    this.carRegistrationNumber,
    this.carChassisNumber,
    this.carEngineNumber,
    this.carManufacturingYear,
    this.carColor,
    this.carFuelType,
    this.items = const [],
    this.payments = const [],
    this.customer,
  });

  final String id;
  final String businessId;
  final String? customerId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final InvoiceStatus status;
  final PaymentStatus paymentStatus;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double additionalCharges;
  final double grandTotal;
  final double amountPaid;
  final double amountOutstanding;
  final String? notes;
  final String? carMake;
  final String? carModel;
  final String? carVariant;
  final String? carRegistrationNumber;
  final String? carChassisNumber;
  final String? carEngineNumber;
  final int? carManufacturingYear;
  final String? carColor;
  final String? carFuelType;
  final List<InvoiceItem> items;
  final List<Payment> payments;
  final Customer? customer;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['invoice_items'];
    final rawPayments = json['payments'];
    final rawCustomer = json['customers'];

    Customer? customer;
    if (rawCustomer is Map<String, dynamic>) {
      customer = Customer.fromJson(rawCustomer);
    } else if (rawCustomer is Map) {
      customer = Customer.fromJson(Map<String, dynamic>.from(rawCustomer));
    }

    return Invoice(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String? ?? customer?.id,
      invoiceNumber: json['invoice_number'] as String,
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      status: _parseInvoiceStatus(json['status'] as String?),
      paymentStatus: _parsePaymentStatus(json['payment_status'] as String?),
      subtotal: _toDouble(json['subtotal']),
      discountAmount: _toDouble(json['discount_amount']),
      taxAmount: _toDouble(json['tax_amount']),
      additionalCharges: _toDouble(json['additional_charges']),
      grandTotal: _toDouble(json['grand_total']),
      amountPaid: _toDouble(json['amount_paid']),
      amountOutstanding: _toDouble(json['amount_outstanding']),
      notes: json['notes'] as String?,
      carMake: json['car_make'] as String?,
      carModel: json['car_model'] as String?,
      carVariant: json['car_variant'] as String?,
      carRegistrationNumber: json['car_registration_number'] as String?,
      carChassisNumber: json['car_chassis_number'] as String?,
      carEngineNumber: json['car_engine_number'] as String?,
      carManufacturingYear: _toInt(json['car_manufacturing_year']),
      carColor: json['car_color'] as String?,
      carFuelType: json['car_fuel_type'] as String?,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => InvoiceItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      payments: rawPayments is List
          ? rawPayments
              .whereType<Map>()
              .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      customer: customer,
    );
  }

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'customer_id': customerId,
        'invoice_number': invoiceNumber,
        'invoice_date': invoiceDate.toIso8601String().split('T').first,
        'status': status.name,
        'payment_status': paymentStatus.name,
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'additional_charges': additionalCharges,
        'grand_total': grandTotal,
        'amount_paid': amountPaid,
        'amount_outstanding': amountOutstanding,
        'notes': notes,
        'car_make': carMake,
        'car_model': carModel,
        'car_variant': carVariant,
        'car_registration_number': carRegistrationNumber,
        'car_chassis_number': carChassisNumber,
        'car_engine_number': carEngineNumber,
        'car_manufacturing_year': carManufacturingYear,
        'car_color': carColor,
        'car_fuel_type': carFuelType,
      };

  static InvoiceStatus _parseInvoiceStatus(String? value) {
    switch (value) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      case 'issued':
      default:
        return InvoiceStatus.issued;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, businessId, invoiceNumber, paymentStatus, grandTotal];
}
