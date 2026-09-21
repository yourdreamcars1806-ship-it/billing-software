import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../models/invoice.dart';
import '../../../models/payment.dart';
import '../../../repositories/payment_repository.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../business_selection/providers/business_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../invoices/providers/invoices_provider.dart';

class AddPaymentSheet extends ConsumerStatefulWidget {
  const AddPaymentSheet({super.key, required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<AddPaymentSheet> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController.text =
        widget.invoice.amountOutstanding.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    setState(() => _isSaving = true);

    try {
      final payment = Payment(
        id: '',
        businessId: business.id,
        invoiceId: widget.invoice.id,
        amount: amount,
        paymentDate: AppDateUtils.today(),
        paymentMethod: _method,
        referenceNumber: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await ref.read(paymentRepositoryProvider).addPayment(payment);
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardStatsProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Payment',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs. ',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMethod>(
                value: _method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(Payment.label(m)),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _method = value);
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Reference Number',
                  hintText: 'UPI ref, cheque no., etc.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: _isSaving,
                loadingLabel: 'Saving payment…',
                onPressed: _save,
                label: 'Record Payment',
              ),
            ],
          ),
        ),
        if (_isSaving)
          const LoadingOverlay(
            isVisible: true,
            message: 'Saving payment…',
          ),
      ],
    );
  }
}
