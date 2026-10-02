import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../models/delivery_note.dart';
import '../../../models/invoice.dart';
import '../../../repositories/delivery_note_repository.dart';
import '../../../repositories/invoice_repository.dart';
import '../../../services/pdf_delivery_note_service.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';

class DeliveryNoteEditorScreen extends ConsumerStatefulWidget {
  const DeliveryNoteEditorScreen({
    super.key,
    this.noteId,
    this.initialNoteNo,
    this.allocError,
  });

  final String? noteId;
  final String? initialNoteNo;
  final String? allocError;

  @override
  ConsumerState<DeliveryNoteEditorScreen> createState() =>
      _DeliveryNoteEditorScreenState();
}

class _DeliveryNoteEditorScreenState
    extends ConsumerState<DeliveryNoteEditorScreen> {
  late DeliveryNoteFormData _form;
  String? _editingId;
  String? _linkedInvoiceId;
  List<Invoice> _invoices = [];
  bool _loading = true;
  bool _saving = false;
  bool _busy = false;
  String? _error;
  String? _message;
  bool _changed = false;

  final _pdf = PdfDeliveryNoteService();

  @override
  void initState() {
    super.initState();
    _form = DeliveryNoteFormData.empty(noteNo: widget.initialNoteNo ?? '');
    _editingId = widget.noteId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) {
      setState(() {
        _loading = false;
        _error = 'No active business';
      });
      return;
    }

    _form = DeliveryNoteFormData.empty(
      noteNo: widget.initialNoteNo ?? '',
      businessName: business.name,
    );
    if (widget.allocError != null) {
      _error = widget.allocError;
    }

    try {
      final invoices =
          await ref.read(invoiceRepositoryProvider).getInvoices(business.id);
      if (widget.noteId != null) {
        final rows = await ref
            .read(deliveryNoteRepositoryProvider)
            .listDeliveryNotes(business.id);
        final row = rows.where((r) => r.id == widget.noteId).firstOrNull;
        if (row != null) {
          _editingId = row.id;
          _linkedInvoiceId = row.invoiceId;
          _form = row.toForm(businessName: business.name);
          _message = 'Editing ${row.deliveryNoteNumber}';
        } else {
          _error = 'Delivery note not found';
        }
      } else if ((_form.deliveryNoteNo).isNotEmpty) {
        _message = 'New note ${_form.deliveryNoteNo}';
      }
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  DeliveryNoteFormData _prepared() {
    final copy = _form.copy();
    if (copy.declarationName.trim().isEmpty) {
      copy.declarationName = copy.customerName;
    }
    if (copy.customerSignName.trim().isEmpty) {
      copy.customerSignName = copy.customerName;
    }
    final total = double.tryParse(copy.totalVehiclePrice.replaceAll(',', ''));
    final received = double.tryParse(copy.amountReceived.replaceAll(',', ''));
    if (copy.balanceAmount.trim().isEmpty &&
        total != null &&
        received != null) {
      final bal = ((total - received) * 100).round() / 100;
      copy.balanceAmount = bal.toString();
    }
    return copy;
  }

  void _patch(void Function(DeliveryNoteFormData f) fn) {
    setState(() {
      fn(_form);
      _changed = true;
    });
  }

  void _applyInvoice(String? id) {
    if (id == null || id.isEmpty) {
      setState(() {
        _linkedInvoiceId = null;
      });
      return;
    }
    final inv = _invoices.where((i) => i.id == id).firstOrNull;
    if (inv == null) return;
    final modelVariant = [inv.carModel, inv.carVariant]
        .whereType<String>()
        .where((x) => x.trim().isNotEmpty)
        .map((x) => x.trim())
        .join(' / ');
    _patch((f) {
      f.customerName = inv.customer?.name ?? '';
      f.customerMobile = inv.customer?.mobile ?? '';
      f.customerAddress = inv.customer?.address ?? '';
      f.declarationName = inv.customer?.name ?? '';
      f.customerSignName = inv.customer?.name ?? '';
      f.carMake = inv.carMake ?? '';
      f.carModelVariant = modelVariant;
      f.carRegistrationNumber = inv.carRegistrationNumber ?? '';
      f.carManufacturingYear =
          inv.carManufacturingYear != null ? '${inv.carManufacturingYear}' : '';
      f.carColor = inv.carColor ?? '';
      f.carFuelType = inv.carFuelType ?? '';
      f.carChassisNumber = inv.carChassisNumber ?? '';
      f.carEngineNumber = inv.carEngineNumber ?? '';
      f.totalVehiclePrice = '${inv.grandTotal}';
      f.amountReceived = '${inv.amountPaid}';
      f.balanceAmount = '${inv.amountOutstanding}';
    });
    setState(() {
      _linkedInvoiceId = id;
      _message = 'Filled from invoice ${inv.invoiceNumber}';
    });
  }

  Future<void> _save() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var data = _prepared();
      if (data.deliveryNoteNo.trim().isEmpty) {
        final no = await ref
            .read(deliveryNoteRepositoryProvider)
            .allocateDeliveryNoteNumber(business.id);
        data.deliveryNoteNo = no;
        _form.deliveryNoteNo = no;
      }
      final result =
          await ref.read(deliveryNoteRepositoryProvider).saveDeliveryNote(
                businessId: business.id,
                form: data,
                id: _editingId,
                invoiceId: _linkedInvoiceId,
              );
      if (!result.success || result.row == null) {
        setState(() => _error = result.error ?? 'Save failed');
        return;
      }
      setState(() {
        _editingId = result.row!.id;
        _form = result.row!.toForm(businessName: business.name);
        _message = 'Saved ${result.row!.deliveryNoteNumber}';
        _changed = true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    if (_editingId == null) {
      setState(() => _error = 'Save the note first, then change status');
      return;
    }

    String? cancelReason = _form.cancelReason;
    if (status == 'cancelled') {
      final controller = TextEditingController(text: cancelReason);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel delivery?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Cancel reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel deal'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      cancelReason = controller.text;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(deliveryNoteRepositoryProvider)
          .updateDeliveryNoteStatus(
            businessId: business.id,
            id: _editingId!,
            status: status,
            cancelReason: cancelReason,
          );
      if (!result.success || result.row == null) {
        setState(() => _error = result.error ?? 'Status update failed');
        return;
      }
      setState(() {
        _form = result.row!.toForm(businessName: business.name);
        _changed = true;
        _message = status == 'confirmed'
            ? 'Confirmed · ${result.row!.deliveryNoteNumber}'
            : status == 'cancelled'
                ? 'Cancelled · ${result.row!.deliveryNoteNumber}'
                : 'Moved to draft · ${result.row!.deliveryNoteNumber}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdfShare() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() => _busy = true);
    try {
      await _pdf.sharePdf(business: business, data: _prepared());
    } catch (e) {
      setState(() => _error = 'PDF failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pdfPrint() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    setState(() => _busy = true);
    try {
      await _pdf.printPdf(business: business, data: _prepared());
    } catch (e) {
      setState(() => _error = 'Print failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncCancelTerms() {
    final business = ref.read(activeBusinessProvider);
    _patch((f) {
      f.cancellationTerms = DeliveryNoteFormData.defaultCancellationTerms(
        gstPercent: f.cancelGstPercent,
        paperFee: f.paperProcessingFee,
        businessName: business?.name ?? 'Your Dream Cars',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final status = _form.deliveryStatus;

    return AppScaffold(
        title: _form.deliveryNoteNo.isEmpty
            ? 'New delivery note'
            : _form.deliveryNoteNo,
        showBusinessSwitcher: false,
        showBack: true,
        fallbackRoute: '/delivery-notes',
        actions: [
          IconButton(
            tooltip: 'PDF',
            onPressed: _busy || _loading ? null : _pdfShare,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
        bottomBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(
                        label: 'Draft',
                        selected: status == 'draft',
                        color: AppColors.slate600,
                        onTap: () => _setStatus('draft'),
                      ),
                      _StatusChip(
                        label: 'Confirm',
                        selected: status == 'confirmed',
                        color: AppColors.success,
                        onTap: () => _setStatus('confirmed'),
                      ),
                      _StatusChip(
                        label: 'Cancel',
                        selected: status == 'cancelled',
                        color: AppColors.error,
                        onTap: () => _setStatus('cancelled'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || _loading ? null : _pdfPrint,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: brand),
                        onPressed: _saving || _loading ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_editingId == null ? 'Save' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_message != null)
                    _Msg(text: _message!, ok: true, onClose: () {
                      setState(() => _message = null);
                    }),
                  if (_error != null)
                    _Msg(text: _error!, ok: false, onClose: () {
                      setState(() => _error = null);
                    }),

                  SoftSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOAD FROM INVOICE (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.slate500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_linkedInvoiceId ?? ''),
                          initialValue: _linkedInvoiceId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          hint: const Text('— Select invoice to auto-fill —'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('— None —'),
                            ),
                            ..._invoices.map(
                              (inv) => DropdownMenuItem(
                                value: inv.id,
                                child: Text(
                                  '${inv.invoiceNumber} · ${inv.customer?.name ?? 'Customer'} · ${CurrencyUtils.format(inv.grandTotal)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => _applyInvoice(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _Section(
                    step: '01',
                    title: 'Delivery header',
                    subtitle: 'Note number, date & time',
                    icon: Icons.description_rounded,
                    brand: brand,
                    children: [
                      _Field(
                        label: 'Delivery Note No.',
                        child: TextFormField(
                          initialValue: _form.deliveryNoteNo,
                          onChanged: (v) =>
                              _patch((f) => f.deliveryNoteNo = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Date',
                        child: TextFormField(
                          initialValue: _form.deliveryDate,
                          onChanged: (v) => _patch((f) => f.deliveryDate = v),
                          decoration: _dec(hint: 'yyyy-MM-dd'),
                        ),
                      ),
                      _Field(
                        label: 'Delivery Time',
                        child: TextFormField(
                          initialValue: _form.deliveryTime,
                          onChanged: (v) => _patch((f) => f.deliveryTime = v),
                          decoration: _dec(hint: 'e.g. 04:30 PM'),
                        ),
                      ),
                    ],
                  ),

                  _Section(
                    step: '02',
                    title: 'Customer details',
                    subtitle: 'Buyer identity & contact',
                    icon: Icons.person_rounded,
                    brand: brand,
                    children: [
                      _Field(
                        label: 'Customer Name',
                        child: TextFormField(
                          initialValue: _form.customerName,
                          onChanged: (v) => _patch((f) => f.customerName = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Address',
                        child: TextFormField(
                          initialValue: _form.customerAddress,
                          onChanged: (v) =>
                              _patch((f) => f.customerAddress = v),
                          maxLines: 2,
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Mobile No.',
                        child: TextFormField(
                          initialValue: _form.customerMobile,
                          onChanged: (v) =>
                              _patch((f) => f.customerMobile = v),
                          keyboardType: TextInputType.phone,
                          decoration: _dec(),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'ID Proof',
                              child: TextFormField(
                                initialValue: _form.idProof,
                                onChanged: (v) => _patch((f) => f.idProof = v),
                                decoration: _dec(hint: 'Aadhaar / DL'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: 'ID No.',
                              child: TextFormField(
                                initialValue: _form.idNo,
                                onChanged: (v) => _patch((f) => f.idNo = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  _Section(
                    step: '03',
                    title: 'Vehicle details',
                    subtitle: 'Car identity & readings',
                    icon: Icons.directions_car_rounded,
                    brand: brand,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Make / Brand',
                              child: TextFormField(
                                initialValue: _form.carMake,
                                onChanged: (v) =>
                                    _patch((f) => f.carMake = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: 'Model / Variant',
                              child: TextFormField(
                                initialValue: _form.carModelVariant,
                                onChanged: (v) =>
                                    _patch((f) => f.carModelVariant = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _Field(
                        label: 'Registration No.',
                        child: TextFormField(
                          initialValue: _form.carRegistrationNumber,
                          onChanged: (v) =>
                              _patch((f) => f.carRegistrationNumber = v),
                          decoration: _dec(),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Year',
                              child: TextFormField(
                                initialValue: _form.carManufacturingYear,
                                onChanged: (v) =>
                                    _patch((f) => f.carManufacturingYear = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: 'Colour',
                              child: TextFormField(
                                initialValue: _form.carColor,
                                onChanged: (v) =>
                                    _patch((f) => f.carColor = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Fuel',
                              child: TextFormField(
                                initialValue: _form.carFuelType,
                                onChanged: (v) =>
                                    _patch((f) => f.carFuelType = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              label: 'Odometer (KM)',
                              child: TextFormField(
                                initialValue: _form.odometerKm,
                                onChanged: (v) =>
                                    _patch((f) => f.odometerKm = v),
                                decoration: _dec(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _Field(
                        label: 'Chassis No.',
                        child: TextFormField(
                          initialValue: _form.carChassisNumber,
                          onChanged: (v) =>
                              _patch((f) => f.carChassisNumber = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Engine No.',
                        child: TextFormField(
                          initialValue: _form.carEngineNumber,
                          onChanged: (v) =>
                              _patch((f) => f.carEngineNumber = v),
                          decoration: _dec(),
                        ),
                      ),
                    ],
                  ),

                  _Section(
                    step: '04',
                    title: 'Payment details',
                    subtitle: 'Price, token & modes',
                    icon: Icons.payments_rounded,
                    brand: brand,
                    children: [
                      _Field(
                        label: 'Total Vehicle Price',
                        child: TextFormField(
                          initialValue: _form.totalVehiclePrice,
                          onChanged: (v) =>
                              _patch((f) => f.totalVehiclePrice = v),
                          keyboardType: TextInputType.number,
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Amount Received',
                        child: TextFormField(
                          initialValue: _form.amountReceived,
                          onChanged: (v) =>
                              _patch((f) => f.amountReceived = v),
                          keyboardType: TextInputType.number,
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Balance Amount',
                        child: TextFormField(
                          initialValue: _form.balanceAmount,
                          onChanged: (v) =>
                              _patch((f) => f.balanceAmount = v),
                          keyboardType: TextInputType.number,
                          decoration: _dec(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PAYMENT MODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            label: 'Cash',
                            checked: _form.paymentModes.cash,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.paymentModes =
                                  f.paymentModes.copyWith(cash: v),
                            ),
                          ),
                          _Chip(
                            label: 'UPI',
                            checked: _form.paymentModes.upi,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.paymentModes =
                                  f.paymentModes.copyWith(upi: v),
                            ),
                          ),
                          _Chip(
                            label: 'Bank Transfer',
                            checked: _form.paymentModes.bankTransfer,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.paymentModes =
                                  f.paymentModes.copyWith(bankTransfer: v),
                            ),
                          ),
                          _Chip(
                            label: 'Finance',
                            checked: _form.paymentModes.finance,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.paymentModes =
                                  f.paymentModes.copyWith(finance: v),
                            ),
                          ),
                          _Chip(
                            label: 'Other',
                            checked: _form.paymentModes.other,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.paymentModes =
                                  f.paymentModes.copyWith(other: v),
                            ),
                          ),
                        ],
                      ),
                      if (_form.paymentModes.other) ...[
                        const SizedBox(height: 8),
                        _Field(
                          label: 'Other payment detail',
                          child: TextFormField(
                            initialValue: _form.paymentOther,
                            onChanged: (v) =>
                                _patch((f) => f.paymentOther = v),
                            decoration: _dec(),
                          ),
                        ),
                      ],
                    ],
                  ),

                  _Section(
                    step: '05',
                    title: 'Documents handed over',
                    subtitle: 'RC, keys & extras',
                    icon: Icons.folder_rounded,
                    brand: brand,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(
                            label: 'RC',
                            checked: _form.docs.rc,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(rc: v),
                            ),
                          ),
                          _Chip(
                            label: 'Insurance',
                            checked: _form.docs.insurance,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(insurance: v),
                            ),
                          ),
                          _Chip(
                            label: 'PUC',
                            checked: _form.docs.puc,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(puc: v),
                            ),
                          ),
                          _Chip(
                            label: 'Service Records',
                            checked: _form.docs.serviceRecords,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) =>
                                  f.docs = f.docs.copyWith(serviceRecords: v),
                            ),
                          ),
                          _Chip(
                            label: 'Keys',
                            checked: _form.docs.keys,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(keys: v),
                            ),
                          ),
                          _Chip(
                            label: 'Spare Key',
                            checked: _form.docs.spareKey,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(spareKey: v),
                            ),
                          ),
                          _Chip(
                            label: 'Other',
                            checked: _form.docs.other,
                            brand: brand,
                            onChanged: (v) => _patch(
                              (f) => f.docs = f.docs.copyWith(other: v),
                            ),
                          ),
                        ],
                      ),
                      if (_form.docs.other) ...[
                        const SizedBox(height: 8),
                        _Field(
                          label: 'Other documents',
                          child: TextFormField(
                            initialValue: _form.docsOther,
                            onChanged: (v) => _patch((f) => f.docsOther = v),
                            decoration: _dec(),
                          ),
                        ),
                      ],
                    ],
                  ),

                  _Section(
                    step: '06',
                    title: 'Signatures',
                    subtitle: 'Customer & dealership',
                    icon: Icons.draw_rounded,
                    brand: brand,
                    children: [
                      _Field(
                        label: 'Declaration name',
                        child: TextFormField(
                          initialValue: _form.declarationName,
                          onChanged: (v) =>
                              _patch((f) => f.declarationName = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Customer sign name',
                        child: TextFormField(
                          initialValue: _form.customerSignName,
                          onChanged: (v) =>
                              _patch((f) => f.customerSignName = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Customer sign date & time',
                        child: TextFormField(
                          initialValue: _form.customerSignDatetime,
                          onChanged: (v) =>
                              _patch((f) => f.customerSignDatetime = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Authorized sign name',
                        child: TextFormField(
                          initialValue: _form.authSignName,
                          onChanged: (v) =>
                              _patch((f) => f.authSignName = v),
                          decoration: _dec(),
                        ),
                      ),
                      _Field(
                        label: 'Handed over by',
                        child: TextFormField(
                          initialValue: _form.handedOverBy,
                          onChanged: (v) =>
                              _patch((f) => f.handedOverBy = v),
                          decoration: _dec(),
                        ),
                      ),
                    ],
                  ),

                  _Section(
                    step: '07',
                    title: 'Cancellation terms',
                    subtitle: 'GST % & paper fees on print',
                    icon: Icons.gavel_rounded,
                    brand: brand,
                    amber: true,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Print cancellation clause on delivery note',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _form.cancelTermsEnabled,
                        activeThumbColor: brand,
                        onChanged: (v) =>
                            _patch((f) => f.cancelTermsEnabled = v),
                      ),
                      if (_form.cancelTermsEnabled) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Cancel GST %',
                                child: TextFormField(
                                  initialValue: _form.cancelGstPercent,
                                  onChanged: (v) {
                                    _patch((f) => f.cancelGstPercent = v);
                                    _syncCancelTerms();
                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: _dec(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Field(
                                label: 'Paper processing fee',
                                child: TextFormField(
                                  initialValue: _form.paperProcessingFee,
                                  onChanged: (v) {
                                    _patch((f) => f.paperProcessingFee = v);
                                    _syncCancelTerms();
                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: _dec(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _Field(
                          label: 'Cancellation terms text',
                          child: TextFormField(
                            key: ValueKey(
                              'cancel-${_form.cancelGstPercent}-${_form.paperProcessingFee}',
                            ),
                            initialValue: _form.cancellationTerms,
                            onChanged: (v) =>
                                _patch((f) => f.cancellationTerms = v),
                            maxLines: 4,
                            decoration: _dec(),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(_changed),
                    child: const Text('Back to list'),
                  ),
                ],
              ),
    );
  }

  InputDecoration _dec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.brand,
    required this.children,
    this.amber = false,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color brand;
  final List<Widget> children;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final headerBg = amber
        ? const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
          )
        : LinearGradient(
            colors: [
              brand.withValues(alpha: 0.08),
              AppColors.slate50,
              Colors.white,
            ],
          );
    final iconBg = amber ? const Color(0xFFF59E0B) : brand;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftSurface(
        padding: EdgeInsets.zero,
        borderColor: amber
            ? const Color(0xFFFDE68A)
            : AppColors.slate200.withValues(alpha: 0.9),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: headerBg,
                border: const Border(
                  bottom: BorderSide(color: AppColors.slate100),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP $step',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: amber
                                ? const Color(0xFFB45309)
                                : brand,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.checked,
    required this.brand,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final Color brand;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: checked,
      showCheckmark: true,
      onSelected: onChanged,
      selectedColor: brand,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: checked ? Colors.white : AppColors.slate600,
      ),
      side: BorderSide(color: checked ? brand : AppColors.slate200),
      backgroundColor: Colors.white,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : color,
        ),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        backgroundColor: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  const _Msg({required this.text, required this.ok, required this.onClose});
  final String text;
  final bool ok;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: color),
          ),
        ],
      ),
    );
  }
}
