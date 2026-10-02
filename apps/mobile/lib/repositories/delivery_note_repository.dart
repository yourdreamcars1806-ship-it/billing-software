import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/delivery_note.dart';
import '../services/supabase_service.dart';

final deliveryNoteRepositoryProvider = Provider<DeliveryNoteRepository>((ref) {
  return DeliveryNoteRepository(ref.watch(supabaseServiceProvider));
});

class DeliveryNoteSaveResult {
  const DeliveryNoteSaveResult({this.row, this.error});
  final DeliveryNote? row;
  final String? error;
  bool get success => row != null && error == null;
}

class DeliveryNoteDeleteResult {
  const DeliveryNoteDeleteResult({this.success = false, this.error});
  final bool success;
  final String? error;
}

/// Same Supabase API as web `lib/delivery-notes.ts`.
class DeliveryNoteRepository {
  DeliveryNoteRepository(this._supabase);

  final SupabaseService _supabase;

  static double? _numOrNull(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final n = double.tryParse(cleaned);
    if (n == null) return null;
    return (n * 100).round() / 100;
  }

  Map<String, dynamic> _formToRow({
    required String businessId,
    required DeliveryNoteFormData form,
    String? id,
    String? invoiceId,
    String? createdBy,
  }) {
    final row = <String, dynamic>{
      if (id != null) 'id': id,
      'business_id': businessId,
      'invoice_id': invoiceId,
      'delivery_note_number': form.deliveryNoteNo.trim(),
      'delivery_date': form.deliveryDate.trim().isEmpty
          ? DateTime.now().toIso8601String().split('T').first
          : form.deliveryDate.trim(),
      'delivery_time':
          form.deliveryTime.trim().isEmpty ? null : form.deliveryTime.trim(),
      'customer_name': form.customerName.trim(),
      'customer_address': form.customerAddress.trim().isEmpty
          ? null
          : form.customerAddress.trim(),
      'customer_mobile': form.customerMobile.trim().isEmpty
          ? null
          : form.customerMobile.trim(),
      'id_proof': form.idProof.trim().isEmpty ? null : form.idProof.trim(),
      'id_no': form.idNo.trim().isEmpty ? null : form.idNo.trim(),
      'car_make': form.carMake.trim().isEmpty ? null : form.carMake.trim(),
      'car_model_variant': form.carModelVariant.trim().isEmpty
          ? null
          : form.carModelVariant.trim(),
      'car_registration_number': form.carRegistrationNumber.trim().isEmpty
          ? null
          : form.carRegistrationNumber.trim(),
      'car_manufacturing_year': form.carManufacturingYear.trim().isEmpty
          ? null
          : form.carManufacturingYear.trim(),
      'car_color': form.carColor.trim().isEmpty ? null : form.carColor.trim(),
      'car_fuel_type':
          form.carFuelType.trim().isEmpty ? null : form.carFuelType.trim(),
      'car_chassis_number': form.carChassisNumber.trim().isEmpty
          ? null
          : form.carChassisNumber.trim(),
      'car_engine_number': form.carEngineNumber.trim().isEmpty
          ? null
          : form.carEngineNumber.trim(),
      'odometer_km':
          form.odometerKm.trim().isEmpty ? null : form.odometerKm.trim(),
      'total_vehicle_price': _numOrNull(form.totalVehiclePrice),
      'amount_received': _numOrNull(form.amountReceived),
      'balance_amount': _numOrNull(form.balanceAmount),
      'payment_modes': form.paymentModes.toJson(),
      'payment_other':
          form.paymentOther.trim().isEmpty ? null : form.paymentOther.trim(),
      'docs': form.docs.toJson(),
      'docs_other':
          form.docsOther.trim().isEmpty ? null : form.docsOther.trim(),
      'declaration_name': form.declarationName.trim().isEmpty
          ? null
          : form.declarationName.trim(),
      'customer_sign_name': form.customerSignName.trim().isEmpty
          ? null
          : form.customerSignName.trim(),
      'customer_sign_datetime': form.customerSignDatetime.trim().isEmpty
          ? null
          : form.customerSignDatetime.trim(),
      'auth_sign_name':
          form.authSignName.trim().isEmpty ? null : form.authSignName.trim(),
      'handed_over_by':
          form.handedOverBy.trim().isEmpty ? null : form.handedOverBy.trim(),
      'cancel_terms_enabled': form.cancelTermsEnabled,
      'cancel_gst_percent': _numOrNull(form.cancelGstPercent) ?? 18,
      'paper_processing_fee': _numOrNull(form.paperProcessingFee),
      'cancellation_terms': form.cancellationTerms.trim().isEmpty
          ? null
          : form.cancellationTerms.trim(),
      'delivery_status': form.deliveryStatus.trim().isEmpty
          ? 'draft'
          : form.deliveryStatus.trim(),
      'cancel_reason':
          form.cancelReason.trim().isEmpty ? null : form.cancelReason.trim(),
      if (createdBy != null) 'created_by': createdBy,
    };
    return row;
  }

  Future<List<DeliveryNote>> listDeliveryNotes(String businessId) async {
    try {
      final response = await _supabase.client
          .from(AppConstants.tableDeliveryNotes)
          .select('*')
          .eq('business_id', businessId)
          .order('delivery_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(200);
      return (response as List<dynamic>)
          .map(
            (row) =>
                DeliveryNote.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (e) {
      throw NetworkException('Failed to load delivery notes: $e');
    }
  }

  Future<String> allocateDeliveryNoteNumber(String businessId) async {
    final data = await _supabase.client.rpc(
      'next_delivery_note_number',
      params: {'p_business_id': businessId},
    );
    if (data == null) {
      throw NetworkException('Could not allocate delivery note number');
    }
    return data.toString();
  }

  Future<DeliveryNoteSaveResult> saveDeliveryNote({
    required String businessId,
    required DeliveryNoteFormData form,
    String? id,
    String? invoiceId,
  }) async {
    if (form.customerName.trim().isEmpty) {
      return const DeliveryNoteSaveResult(error: 'Customer name is required');
    }
    if (form.deliveryNoteNo.trim().isEmpty) {
      return const DeliveryNoteSaveResult(
        error: 'Delivery note number is required',
      );
    }

    final session = _supabase.client.auth.currentSession;
    if (session?.user == null) {
      return const DeliveryNoteSaveResult(error: 'Session expired');
    }

    try {
      final payload = _formToRow(
        businessId: businessId,
        form: form,
        id: id,
        invoiceId: invoiceId,
        createdBy: id == null ? session!.user.id : null,
      );

      if (id != null) {
        final data = await _supabase.client
            .from(AppConstants.tableDeliveryNotes)
            .update(payload)
            .eq('id', id)
            .eq('business_id', businessId)
            .select('*')
            .single();
        return DeliveryNoteSaveResult(
          row: DeliveryNote.fromJson(Map<String, dynamic>.from(data)),
        );
      }

      final data = await _supabase.client
          .from(AppConstants.tableDeliveryNotes)
          .insert(payload)
          .select('*')
          .single();
      return DeliveryNoteSaveResult(
        row: DeliveryNote.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      return DeliveryNoteSaveResult(error: e.toString());
    }
  }

  Future<DeliveryNoteSaveResult> updateDeliveryNoteStatus({
    required String businessId,
    required String id,
    required String status,
    String? cancelReason,
  }) async {
    try {
      final patch = <String, dynamic>{
        'delivery_status': status,
        'status_changed_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (status == 'cancelled') {
        patch['cancel_reason'] =
            cancelReason?.trim().isEmpty == true ? null : cancelReason?.trim();
      }
      final data = await _supabase.client
          .from(AppConstants.tableDeliveryNotes)
          .update(patch)
          .eq('id', id)
          .eq('business_id', businessId)
          .select('*')
          .single();
      return DeliveryNoteSaveResult(
        row: DeliveryNote.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      return DeliveryNoteSaveResult(error: e.toString());
    }
  }

  Future<DeliveryNoteDeleteResult> deleteDeliveryNote(
    String businessId,
    String id,
  ) async {
    try {
      final deleted = await _supabase.client
          .from(AppConstants.tableDeliveryNotes)
          .delete()
          .eq('id', id)
          .eq('business_id', businessId)
          .select('id');
      final list = deleted as List<dynamic>?;
      if (list == null || list.isEmpty) {
        return const DeliveryNoteDeleteResult(
          error:
              'Delivery note was not deleted from database (no access or already removed)',
        );
      }
      return const DeliveryNoteDeleteResult(success: true);
    } catch (e) {
      return DeliveryNoteDeleteResult(error: e.toString());
    }
  }
}
