import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'supabase_service.dart';

final createInvoiceServiceProvider = Provider<CreateInvoiceService>((ref) {
  return CreateInvoiceService(ref.watch(supabaseServiceProvider));
});

class CreateInvoiceLine {
  const CreateInvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    this.taxRate = 0,
    this.productId,
    this.productVariantId,
    this.size,
    this.color,
    this.barcode,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxRate;
  final String? productId;
  final String? productVariantId;
  final String? size;
  final String? color;
  final String? barcode;
}

class CreateInvoiceInput {
  const CreateInvoiceInput({
    required this.businessId,
    required this.items,
    this.customerId,
    this.customerName,
    this.customerMobile,
    this.invoiceDate,
    this.discountAmount = 0,
    this.additionalCharges = 0,
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
    this.initialPaymentAmount,
    this.initialPaymentMethod = 'cash',
    this.autoWhatsapp = true,
  });

  final String businessId;
  final String? customerId;
  final String? customerName;
  final String? customerMobile;
  final String? invoiceDate;
  final List<CreateInvoiceLine> items;
  final double discountAmount;
  final double additionalCharges;
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
  final double? initialPaymentAmount;
  final String initialPaymentMethod;
  final bool autoWhatsapp;
}

class CreateInvoiceResult {
  const CreateInvoiceResult({
    required this.success,
    this.invoice,
    this.whatsappSent,
    this.whatsappSkipped,
    this.whatsappError,
    this.error,
  });

  final bool success;
  final Map<String, dynamic>? invoice;
  final bool? whatsappSent;
  final String? whatsappSkipped;
  final String? whatsappError;
  final String? error;

  String? get invoiceId => invoice?['id'] as String?;
}

class CreateInvoiceService {
  CreateInvoiceService(this._supabase);

  final SupabaseService _supabase;

  static double _round2(double n) =>
      (n * 100).roundToDouble() / 100;

  Future<CreateInvoiceResult> create(CreateInvoiceInput input) async {
    if (input.businessId.isEmpty || input.items.isEmpty) {
      return const CreateInvoiceResult(
        success: false,
        error: 'business_id and items required',
      );
    }

    final user = _supabase.currentUser;
    if (user == null) {
      return const CreateInvoiceResult(
        success: false,
        error: 'Session expired. Please login again.',
      );
    }

    final client = _supabase.client;

    final membership = await client
        .from(AppConstants.tableBusinessUsers)
        .select('id')
        .eq('business_id', input.businessId)
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    if (membership == null) {
      return const CreateInvoiceResult(
        success: false,
        error: 'No access to this business',
      );
    }

    final invoiceNumber = await client.rpc(
      'next_invoice_number',
      params: {'p_business_id': input.businessId},
    );

    if (invoiceNumber == null || invoiceNumber.toString().isEmpty) {
      return const CreateInvoiceResult(
        success: false,
        error: 'Failed to allocate invoice number. Check invoice settings.',
      );
    }

    var subtotal = 0.0;
    var taxAmount = 0.0;

    final variantIds = input.items
        .map((i) => i.productVariantId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final variantBarcode = <String, String>{};
    if (variantIds.isNotEmpty) {
      final variants = await client
          .from(AppConstants.tableProductVariants)
          .select('id, barcode')
          .eq('business_id', input.businessId)
          .inFilter('id', variantIds);
      for (final v in variants as List) {
        final map = Map<String, dynamic>.from(v as Map);
        final bc = map['barcode'] as String?;
        if (bc != null && bc.isNotEmpty) {
          variantBarcode[map['id'] as String] = bc;
        }
      }
    }

    final computedItems = <Map<String, dynamic>>[];
    for (var index = 0; index < input.items.length; index++) {
      final item = input.items[index];
      final qty = item.quantity;
      final price = item.unitPrice;
      final discount = item.discountAmount;
      final taxRate = item.taxRate;
      final taxable = math.max(qty * price - discount, 0);
      final tax = (taxable * taxRate) / 100;
      final lineTotal = taxable + tax;
      subtotal += qty * price;
      taxAmount += tax;
      final barcode = item.barcode ??
          (item.productVariantId != null
              ? variantBarcode[item.productVariantId!]
              : null);
      computedItems.add({
        'business_id': input.businessId,
        'description': item.description,
        'quantity': qty,
        'unit_price': price,
        'discount_amount': discount,
        'tax_rate': taxRate,
        'tax_amount': _round2(tax),
        'line_total': _round2(lineTotal),
        'product_id': item.productId,
        'product_variant_id': item.productVariantId,
        'size': item.size,
        'color': item.color,
        'barcode': barcode,
        'sort_order': index,
      });
    }

    final discountAmount = input.discountAmount;
    final additionalCharges = input.additionalCharges;
    final itemsNet =
        computedItems.fold<double>(0, (s, i) => s + (i['line_total'] as double));
    final grandTotal = _round2(itemsNet - discountAmount + additionalCharges);

    String? customerId = input.customerId;
    final typedName = (input.customerName ?? '').trim();
    final typedMobile =
        (input.customerMobile ?? '').trim().replaceAll(RegExp(r'\s+'), '');

    if (customerId == null && (typedName.isNotEmpty || typedMobile.isNotEmpty)) {
      String? existingId;

      if (typedMobile.isNotEmpty) {
        final digits = typedMobile.replaceAll(RegExp(r'\D'), '');
        final last10 =
            digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
        final mobileMatches = await client
            .from(AppConstants.tableCustomers)
            .select('id, mobile')
            .eq('business_id', input.businessId)
            .eq('is_active', true)
            .not('mobile', 'is', null)
            .limit(50);
        for (final c in mobileMatches as List) {
          final map = Map<String, dynamic>.from(c as Map);
          final m = (map['mobile'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
          if (m == digits ||
              (last10.length == 10 && m.endsWith(last10)) ||
              (map['mobile'] as String? ?? '').trim() == typedMobile) {
            existingId = map['id'] as String;
            break;
          }
        }
      }

      if (existingId == null && typedName.isNotEmpty) {
        final byName = await client
            .from(AppConstants.tableCustomers)
            .select('id')
            .eq('business_id', input.businessId)
            .eq('is_active', true)
            .ilike('name', typedName)
            .limit(1)
            .maybeSingle();
        if (byName != null) existingId = byName['id'] as String?;
      }

      if (existingId != null) {
        customerId = existingId;
        if (typedMobile.isNotEmpty || typedName.isNotEmpty) {
          await client.from(AppConstants.tableCustomers).update({
            if (typedMobile.isNotEmpty) 'mobile': typedMobile,
            if (typedName.isNotEmpty) 'name': typedName,
          }).eq('id', existingId).eq('business_id', input.businessId);
        }
      } else {
        final name = typedName.isNotEmpty
            ? typedName
            : (typedMobile.isNotEmpty
                ? 'Customer ${typedMobile.substring(math.max(0, typedMobile.length - 4))}'
                : 'Walk-in');
        final created = await client
            .from(AppConstants.tableCustomers)
            .insert({
              'business_id': input.businessId,
              'name': name,
              'mobile': typedMobile.isEmpty ? null : typedMobile,
              'is_active': true,
            })
            .select('id')
            .single();
        customerId = created['id'] as String?;
      }
    }

    final today = DateTime.now();
    final dateStr = input.invoiceDate ??
        '${today.year.toString().padLeft(4, '0')}-'
            '${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}';

    Map<String, dynamic> invoice;
    try {
      invoice = await client
          .from(AppConstants.tableInvoices)
          .insert({
            'business_id': input.businessId,
            'customer_id': customerId,
            'invoice_number': invoiceNumber.toString(),
            'invoice_date': dateStr,
            'status': 'issued',
            'payment_status': 'pending',
            'subtotal': _round2(subtotal),
            'discount_amount': discountAmount,
            'tax_amount': _round2(taxAmount),
            'additional_charges': additionalCharges,
            'grand_total': grandTotal,
            'amount_paid': 0,
            'amount_outstanding': grandTotal,
            'notes': input.notes,
            'car_make': input.carMake,
            'car_model': input.carModel,
            'car_variant': input.carVariant,
            'car_registration_number': input.carRegistrationNumber,
            'car_chassis_number': input.carChassisNumber,
            'car_engine_number': input.carEngineNumber,
            'car_manufacturing_year': input.carManufacturingYear,
            'car_color': input.carColor,
            'car_fuel_type': input.carFuelType,
            'created_by': user.id,
          })
          .select()
          .single();
    } catch (e) {
      return CreateInvoiceResult(
        success: false,
        error: 'Failed to create invoice: $e',
      );
    }

    final invoiceId = invoice['id'] as String;

    try {
      await client.from(AppConstants.tableInvoiceItems).insert(
            computedItems
                .map((i) => {...i, 'invoice_id': invoiceId})
                .toList(),
          );
    } catch (e) {
      return CreateInvoiceResult(
        success: false,
        error: 'Failed to create line items: $e',
      );
    }

    final payAmt = input.initialPaymentAmount ?? 0;
    if (payAmt > 0) {
      try {
        await client.from(AppConstants.tablePayments).insert({
          'business_id': input.businessId,
          'invoice_id': invoiceId,
          'amount': payAmt,
          'payment_method': input.initialPaymentMethod,
          'created_by': user.id,
        });
      } catch (e) {
        return CreateInvoiceResult(
          success: false,
          error: 'Invoice created but payment failed: $e',
        );
      }
    }

    Map<String, dynamic> refreshed = invoice;
    try {
      refreshed = await client
          .from(AppConstants.tableInvoices)
          .select('*, invoice_items(*), payments(*), customers(*)')
          .eq('id', invoiceId)
          .single();
    } catch (_) {}

    bool? waSent;
    String? waSkipped;
    String? waError;

    if (input.autoWhatsapp) {
      String mobileForWa = typedMobile;
      if (mobileForWa.isEmpty) {
        final cust = refreshed['customers'];
        if (cust is Map) {
          mobileForWa = (cust['mobile'] as String? ?? '').trim();
        }
      }
      if (mobileForWa.isEmpty) {
        waSkipped = 'no customer mobile';
      } else {
        final wa = await sendWhatsappInvoice(
          businessId: input.businessId,
          invoiceId: invoiceId,
          customerMobile: mobileForWa,
        );
        waSent = wa.$1;
        waSkipped = wa.$2;
        waError = wa.$3;
      }
    }

    return CreateInvoiceResult(
      success: true,
      invoice: refreshed,
      whatsappSent: waSent,
      whatsappSkipped: waSkipped,
      whatsappError: waError,
    );
  }

  /// Returns (sent, skipped, error).
  Future<(bool?, String?, String?)> sendWhatsappInvoice({
    required String businessId,
    required String invoiceId,
    required String customerMobile,
  }) async {
    final session = _supabase.client.auth.currentSession;
    if (session == null) {
      return (null, 'not authenticated', null);
    }

    try {
      final res = await _supabase.client.functions.invoke(
        'send-whatsapp-invoice',
        body: {
          'business_id': businessId,
          'invoice_id': invoiceId,
          'customer_mobile': customerMobile.trim(),
        },
      );
      if (res.status >= 200 && res.status < 300) {
        return (true, null, null);
      }
      final data = res.data;
      String err = 'WhatsApp function not available';
      if (data is Map && data['error'] != null) {
        err = data['error'].toString();
      }
      return (null, null, err);
    } catch (_) {
      return (null, 'WhatsApp edge function not reachable', null);
    }
  }
}
