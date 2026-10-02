import 'package:equatable/equatable.dart';

import '../core/utils/currency_utils.dart';

typedef DeliveryNoteStatus = String; // draft | confirmed | cancelled

class DeliveryNotePaymentModes {
  const DeliveryNotePaymentModes({
    this.cash = false,
    this.upi = false,
    this.bankTransfer = false,
    this.finance = false,
    this.other = false,
  });

  final bool cash;
  final bool upi;
  final bool bankTransfer;
  final bool finance;
  final bool other;

  factory DeliveryNotePaymentModes.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    return DeliveryNotePaymentModes(
      cash: m['cash'] == true,
      upi: m['upi'] == true,
      bankTransfer: m['bank_transfer'] == true,
      finance: m['finance'] == true,
      other: m['other'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'cash': cash,
        'upi': upi,
        'bank_transfer': bankTransfer,
        'finance': finance,
        'other': other,
      };

  DeliveryNotePaymentModes copyWith({
    bool? cash,
    bool? upi,
    bool? bankTransfer,
    bool? finance,
    bool? other,
  }) {
    return DeliveryNotePaymentModes(
      cash: cash ?? this.cash,
      upi: upi ?? this.upi,
      bankTransfer: bankTransfer ?? this.bankTransfer,
      finance: finance ?? this.finance,
      other: other ?? this.other,
    );
  }
}

class DeliveryNoteDocs {
  const DeliveryNoteDocs({
    this.rc = true,
    this.insurance = true,
    this.puc = false,
    this.serviceRecords = false,
    this.keys = true,
    this.spareKey = false,
    this.other = false,
  });

  final bool rc;
  final bool insurance;
  final bool puc;
  final bool serviceRecords;
  final bool keys;
  final bool spareKey;
  final bool other;

  factory DeliveryNoteDocs.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    return DeliveryNoteDocs(
      rc: m['rc'] != false,
      insurance: m['insurance'] != false,
      puc: m['puc'] == true,
      serviceRecords: m['service_records'] == true,
      keys: m['keys'] != false,
      spareKey: m['spare_key'] == true,
      other: m['other'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'rc': rc,
        'insurance': insurance,
        'puc': puc,
        'service_records': serviceRecords,
        'keys': keys,
        'spare_key': spareKey,
        'other': other,
      };

  DeliveryNoteDocs copyWith({
    bool? rc,
    bool? insurance,
    bool? puc,
    bool? serviceRecords,
    bool? keys,
    bool? spareKey,
    bool? other,
  }) {
    return DeliveryNoteDocs(
      rc: rc ?? this.rc,
      insurance: insurance ?? this.insurance,
      puc: puc ?? this.puc,
      serviceRecords: serviceRecords ?? this.serviceRecords,
      keys: keys ?? this.keys,
      spareKey: spareKey ?? this.spareKey,
      other: other ?? this.other,
    );
  }
}

/// Form / PDF payload — mirrors web `DeliveryNoteData`.
class DeliveryNoteFormData {
  DeliveryNoteFormData({
    this.deliveryNoteNo = '',
    this.deliveryDate = '',
    this.deliveryTime = '',
    this.customerName = '',
    this.customerAddress = '',
    this.customerMobile = '',
    this.idProof = '',
    this.idNo = '',
    this.carMake = '',
    this.carModelVariant = '',
    this.carRegistrationNumber = '',
    this.carManufacturingYear = '',
    this.carColor = '',
    this.carFuelType = '',
    this.carChassisNumber = '',
    this.carEngineNumber = '',
    this.odometerKm = '',
    this.totalVehiclePrice = '',
    this.amountReceived = '',
    this.balanceAmount = '',
    this.paymentModes = const DeliveryNotePaymentModes(),
    this.paymentOther = '',
    this.docs = const DeliveryNoteDocs(),
    this.docsOther = '',
    this.declarationName = '',
    this.customerSignName = '',
    this.customerSignDatetime = '',
    this.authSignName = '',
    this.handedOverBy = '',
    this.cancelTermsEnabled = true,
    this.cancelGstPercent = '18',
    this.paperProcessingFee = '',
    this.cancellationTerms = '',
    this.deliveryStatus = 'draft',
    this.cancelReason = '',
  });

  String deliveryNoteNo;
  String deliveryDate;
  String deliveryTime;
  String customerName;
  String customerAddress;
  String customerMobile;
  String idProof;
  String idNo;
  String carMake;
  String carModelVariant;
  String carRegistrationNumber;
  String carManufacturingYear;
  String carColor;
  String carFuelType;
  String carChassisNumber;
  String carEngineNumber;
  String odometerKm;
  String totalVehiclePrice;
  String amountReceived;
  String balanceAmount;
  DeliveryNotePaymentModes paymentModes;
  String paymentOther;
  DeliveryNoteDocs docs;
  String docsOther;
  String declarationName;
  String customerSignName;
  String customerSignDatetime;
  String authSignName;
  String handedOverBy;
  bool cancelTermsEnabled;
  String cancelGstPercent;
  String paperProcessingFee;
  String cancellationTerms;
  String deliveryStatus;
  String cancelReason;

  static String defaultCancellationTerms({
    String gstPercent = '18',
    String paperFee = '',
    String businessName = 'Your Dream Cars',
  }) {
    final gst = gstPercent.trim().isEmpty ? '18' : gstPercent.trim();
    final feePart = paperFee.trim().isNotEmpty
        ? 'plus a paper / documentation processing fee of ${CurrencyUtils.format(num.tryParse(paperFee) ?? 0)}'
        : 'plus applicable paper / documentation processing fees';
    return 'Deal cancellation: If this deal or booking is cancelled by the customer for any reason, '
        '$businessName shall be entitled to charge $gst% GST on the applicable amount $feePart. '
        'Token / advance amounts may be adjusted against these charges as per dealership policy.';
  }

  factory DeliveryNoteFormData.empty({
    String noteNo = '',
    String businessName = 'Your Dream Cars',
  }) {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final time =
        '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';
    return DeliveryNoteFormData(
      deliveryNoteNo: noteNo,
      deliveryDate: date,
      deliveryTime: time,
      cancellationTerms: defaultCancellationTerms(businessName: businessName),
    );
  }

  DeliveryNoteFormData copy() {
    return DeliveryNoteFormData(
      deliveryNoteNo: deliveryNoteNo,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      customerName: customerName,
      customerAddress: customerAddress,
      customerMobile: customerMobile,
      idProof: idProof,
      idNo: idNo,
      carMake: carMake,
      carModelVariant: carModelVariant,
      carRegistrationNumber: carRegistrationNumber,
      carManufacturingYear: carManufacturingYear,
      carColor: carColor,
      carFuelType: carFuelType,
      carChassisNumber: carChassisNumber,
      carEngineNumber: carEngineNumber,
      odometerKm: odometerKm,
      totalVehiclePrice: totalVehiclePrice,
      amountReceived: amountReceived,
      balanceAmount: balanceAmount,
      paymentModes: paymentModes,
      paymentOther: paymentOther,
      docs: docs,
      docsOther: docsOther,
      declarationName: declarationName,
      customerSignName: customerSignName,
      customerSignDatetime: customerSignDatetime,
      authSignName: authSignName,
      handedOverBy: handedOverBy,
      cancelTermsEnabled: cancelTermsEnabled,
      cancelGstPercent: cancelGstPercent,
      paperProcessingFee: paperProcessingFee,
      cancellationTerms: cancellationTerms,
      deliveryStatus: deliveryStatus,
      cancelReason: cancelReason,
    );
  }
}

class DeliveryNote extends Equatable {
  const DeliveryNote({
    required this.id,
    required this.businessId,
    required this.deliveryNoteNumber,
    required this.deliveryDate,
    required this.customerName,
    this.invoiceId,
    this.deliveryTime,
    this.customerAddress,
    this.customerMobile,
    this.idProof,
    this.idNo,
    this.carMake,
    this.carModelVariant,
    this.carRegistrationNumber,
    this.carManufacturingYear,
    this.carColor,
    this.carFuelType,
    this.carChassisNumber,
    this.carEngineNumber,
    this.odometerKm,
    this.totalVehiclePrice,
    this.amountReceived,
    this.balanceAmount,
    this.paymentModes = const DeliveryNotePaymentModes(),
    this.paymentOther,
    this.docs = const DeliveryNoteDocs(),
    this.docsOther,
    this.declarationName,
    this.customerSignName,
    this.customerSignDatetime,
    this.authSignName,
    this.handedOverBy,
    this.cancelTermsEnabled = true,
    this.cancelGstPercent = 18,
    this.paperProcessingFee,
    this.cancellationTerms,
    this.deliveryStatus = 'draft',
    this.statusChangedAt,
    this.cancelReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String? invoiceId;
  final String deliveryNoteNumber;
  final String deliveryDate;
  final String? deliveryTime;
  final String customerName;
  final String? customerAddress;
  final String? customerMobile;
  final String? idProof;
  final String? idNo;
  final String? carMake;
  final String? carModelVariant;
  final String? carRegistrationNumber;
  final String? carManufacturingYear;
  final String? carColor;
  final String? carFuelType;
  final String? carChassisNumber;
  final String? carEngineNumber;
  final String? odometerKm;
  final double? totalVehiclePrice;
  final double? amountReceived;
  final double? balanceAmount;
  final DeliveryNotePaymentModes paymentModes;
  final String? paymentOther;
  final DeliveryNoteDocs docs;
  final String? docsOther;
  final String? declarationName;
  final String? customerSignName;
  final String? customerSignDatetime;
  final String? authSignName;
  final String? handedOverBy;
  final bool cancelTermsEnabled;
  final double? cancelGstPercent;
  final double? paperProcessingFee;
  final String? cancellationTerms;
  final String deliveryStatus;
  final DateTime? statusChangedAt;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    return DeliveryNote(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String?,
      deliveryNoteNumber: json['delivery_note_number'] as String? ?? '',
      deliveryDate: (json['delivery_date'] as String?)?.split('T').first ?? '',
      deliveryTime: json['delivery_time'] as String?,
      customerName: json['customer_name'] as String? ?? '',
      customerAddress: json['customer_address'] as String?,
      customerMobile: json['customer_mobile'] as String?,
      idProof: json['id_proof'] as String?,
      idNo: json['id_no'] as String?,
      carMake: json['car_make'] as String?,
      carModelVariant: json['car_model_variant'] as String?,
      carRegistrationNumber: json['car_registration_number'] as String?,
      carManufacturingYear: json['car_manufacturing_year'] as String?,
      carColor: json['car_color'] as String?,
      carFuelType: json['car_fuel_type'] as String?,
      carChassisNumber: json['car_chassis_number'] as String?,
      carEngineNumber: json['car_engine_number'] as String?,
      odometerKm: json['odometer_km'] as String?,
      totalVehiclePrice: _num(json['total_vehicle_price']),
      amountReceived: _num(json['amount_received']),
      balanceAmount: _num(json['balance_amount']),
      paymentModes: DeliveryNotePaymentModes.fromJson(asMap(json['payment_modes'])),
      paymentOther: json['payment_other'] as String?,
      docs: DeliveryNoteDocs.fromJson(asMap(json['docs'])),
      docsOther: json['docs_other'] as String?,
      declarationName: json['declaration_name'] as String?,
      customerSignName: json['customer_sign_name'] as String?,
      customerSignDatetime: json['customer_sign_datetime'] as String?,
      authSignName: json['auth_sign_name'] as String?,
      handedOverBy: json['handed_over_by'] as String?,
      cancelTermsEnabled: json['cancel_terms_enabled'] != false,
      cancelGstPercent: _num(json['cancel_gst_percent']) ?? 18,
      paperProcessingFee: _num(json['paper_processing_fee']),
      cancellationTerms: json['cancellation_terms'] as String?,
      deliveryStatus: (json['delivery_status'] as String?) ?? 'draft',
      statusChangedAt: json['status_changed_at'] != null
          ? DateTime.tryParse(json['status_changed_at'].toString())
          : null,
      cancelReason: json['cancel_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  DeliveryNoteFormData toForm({String businessName = 'Your Dream Cars'}) {
    final gst = cancelGstPercent != null
        ? (cancelGstPercent! % 1 == 0
            ? cancelGstPercent!.toInt().toString()
            : cancelGstPercent!.toString())
        : '18';
    final fee = paperProcessingFee != null
        ? (paperProcessingFee! % 1 == 0
            ? paperProcessingFee!.toInt().toString()
            : paperProcessingFee!.toString())
        : '';
    return DeliveryNoteFormData(
      deliveryNoteNo: deliveryNoteNumber,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime ?? '',
      customerName: customerName,
      customerAddress: customerAddress ?? '',
      customerMobile: customerMobile ?? '',
      idProof: idProof ?? '',
      idNo: idNo ?? '',
      carMake: carMake ?? '',
      carModelVariant: carModelVariant ?? '',
      carRegistrationNumber: carRegistrationNumber ?? '',
      carManufacturingYear: carManufacturingYear ?? '',
      carColor: carColor ?? '',
      carFuelType: carFuelType ?? '',
      carChassisNumber: carChassisNumber ?? '',
      carEngineNumber: carEngineNumber ?? '',
      odometerKm: odometerKm ?? '',
      totalVehiclePrice:
          totalVehiclePrice != null ? totalVehiclePrice.toString() : '',
      amountReceived: amountReceived != null ? amountReceived.toString() : '',
      balanceAmount: balanceAmount != null ? balanceAmount.toString() : '',
      paymentModes: paymentModes,
      paymentOther: paymentOther ?? '',
      docs: docs,
      docsOther: docsOther ?? '',
      declarationName: declarationName ?? '',
      customerSignName: customerSignName ?? '',
      customerSignDatetime: customerSignDatetime ?? '',
      authSignName: authSignName ?? '',
      handedOverBy: handedOverBy ?? '',
      cancelTermsEnabled: cancelTermsEnabled,
      cancelGstPercent: gst,
      paperProcessingFee: fee,
      cancellationTerms: cancellationTerms?.trim().isNotEmpty == true
          ? cancellationTerms!
          : DeliveryNoteFormData.defaultCancellationTerms(
              gstPercent: gst,
              paperFee: fee,
              businessName: businessName,
            ),
      deliveryStatus: deliveryStatus,
      cancelReason: cancelReason ?? '',
    );
  }

  @override
  List<Object?> get props => [id, deliveryNoteNumber, deliveryStatus];
}

class DeliveryNoteSummary {
  const DeliveryNoteSummary({
    required this.total,
    required this.confirmed,
    required this.cancelled,
    required this.draft,
  });

  final int total;
  final int confirmed;
  final int cancelled;
  final int draft;

  static DeliveryNoteSummary fromRows(List<DeliveryNote> rows) {
    var confirmed = 0;
    var cancelled = 0;
    var draft = 0;
    for (final r in rows) {
      final s = r.deliveryStatus;
      if (s == 'confirmed') {
        confirmed++;
      } else if (s == 'cancelled') {
        cancelled++;
      } else {
        draft++;
      }
    }
    return DeliveryNoteSummary(
      total: rows.length,
      confirmed: confirmed,
      cancelled: cancelled,
      draft: draft,
    );
  }
}
