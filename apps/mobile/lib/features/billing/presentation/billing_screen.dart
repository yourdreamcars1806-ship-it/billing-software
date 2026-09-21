import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/payment.dart';
import '../../../repositories/product_repository.dart';
import '../../../services/create_invoice_service.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../../clothing/barcode/models/scanned_product.dart';

class _LineItem {
  _LineItem({
    required this.key,
    required this.description,
    required this.unitPrice,
    required this.taxRate,
    this.barcode,
    this.size,
    this.color,
    this.variantId,
    this.discountAmount = 0,
  });

  final String key;
  String description;
  double unitPrice;
  double taxRate;
  double discountAmount;
  int quantity = 1;
  String? barcode;
  String? size;
  String? color;
  String? variantId;

  double get lineTotal {
    final taxable =
        (quantity * unitPrice - discountAmount).clamp(0.0, double.infinity);
    return taxable + (taxable * taxRate / 100);
  }
}

class _LastScanned {
  const _LastScanned({
    required this.title,
    required this.barcode,
    required this.price,
    this.size,
    this.color,
  });

  final String title;
  final String barcode;
  final double price;
  final String? size;
  final String? color;
}

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');
  final _customerController = TextEditingController();
  final _mobileController = TextEditingController();
  final _manualBarcodeController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _additionalController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _carMakeController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carVariantController = TextEditingController();
  final _carRegistrationController = TextEditingController();
  final _carChassisController = TextEditingController();
  final _carEngineController = TextEditingController();
  final _carYearController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carFuelController = TextEditingController();

  final List<_LineItem> _lines = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _saving = false;
  bool _lookingUpBarcode = false;
  _LastScanned? _lastScanned;

  @override
  void dispose() {
    _customerController.dispose();
    _mobileController.dispose();
    _manualBarcodeController.dispose();
    _paymentAmountController.dispose();
    _discountController.dispose();
    _additionalController.dispose();
    _notesController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _carVariantController.dispose();
    _carRegistrationController.dispose();
    _carChassisController.dispose();
    _carEngineController.dispose();
    _carYearController.dispose();
    _carColorController.dispose();
    _carFuelController.dispose();
    super.dispose();
  }

  double get _subtotal {
    var t = 0.0;
    for (final l in _lines) {
      t += l.quantity * l.unitPrice;
    }
    return t;
  }

  double get _tax {
    var t = 0.0;
    for (final l in _lines) {
      final taxable =
          (l.quantity * l.unitPrice - l.discountAmount).clamp(0.0, double.infinity);
      t += taxable * l.taxRate / 100;
    }
    return t;
  }

  double get _grandTotal {
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final additional = double.tryParse(_additionalController.text.trim()) ?? 0;
    final itemsNet = _lines.fold<double>(0, (s, l) => s + l.lineTotal);
    return (itemsNet - discount + additional).clamp(0.0, double.infinity);
  }

  void _addScannedProduct(ScannedProduct product) {
    setState(() {
      final existing = _lines.indexWhere((l) => l.barcode == product.barcode);
      if (existing >= 0) {
        _lines[existing].quantity += 1;
      } else {
        final title = [
          if (product.brand != null && product.brand!.isNotEmpty) product.brand!,
          product.name,
        ].join(' · ');
        _lines.add(
          _LineItem(
            key: UniqueKey().toString(),
            description: title,
            unitPrice: product.sellingPrice,
            taxRate: product.taxRate,
            barcode: product.barcode,
            size: product.size,
            color: product.color,
            variantId: product.variantId,
          ),
        );
        _lastScanned = _LastScanned(
          title: title,
          barcode: product.barcode,
          price: product.sellingPrice,
          size: product.size,
          color: product.color,
        );
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _scanBarcode() async {
    final result = await context.push<Map<String, dynamic>>('/barcode-scanner');
    if (result == null || !mounted) return;
    _addScannedProduct(ScannedProduct.fromMap(result));
  }

  Future<void> _lookupManualBarcode() async {
    final code = _manualBarcodeController.text.trim();
    if (code.isEmpty) return;
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    setState(() => _lookingUpBarcode = true);
    try {
      final variant = await ref
          .read(productRepositoryProvider)
          .findVariantByBarcode(business.id, code);
      if (!mounted) return;
      if (variant == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product for barcode $code'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      _manualBarcodeController.clear();
      _addScannedProduct(
        ScannedProduct(
          variantId: variant.id,
          barcode: variant.barcode ?? code,
          name: variant.productName ?? 'Product',
          brand: variant.productBrand,
          size: variant.size,
          color: variant.color,
          fabric: variant.fabric,
          sellingPrice: variant.sellingPrice,
          taxRate: variant.taxRate,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lookup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _lookingUpBarcode = false);
    }
  }

  Future<void> _createInvoice() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final isClothing = business.isClothing;

    if (isClothing && _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan at least one product')),
      );
      return;
    }

    if (!isClothing && _lines.isEmpty) {
      final desc = [
        if (_carMakeController.text.trim().isNotEmpty)
          _carMakeController.text.trim(),
        if (_carModelController.text.trim().isNotEmpty)
          _carModelController.text.trim(),
        if (_carRegistrationController.text.trim().isNotEmpty)
          _carRegistrationController.text.trim(),
      ].join(' · ');
      if (desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter vehicle make or registration')),
        );
        return;
      }
      _lines.add(
        _LineItem(
          key: UniqueKey().toString(),
          description: desc,
          unitPrice: _grandTotal > 0 ? _grandTotal : 0,
          taxRate: 0,
        ),
      );
    }

    setState(() => _saving = true);
    try {
      final payText = _paymentAmountController.text.trim();
      final payAmt = payText.isEmpty ? null : double.tryParse(payText);
      final discount = double.tryParse(_discountController.text.trim()) ?? 0;
      final additional = double.tryParse(_additionalController.text.trim()) ?? 0;

      String methodStr = 'cash';
      switch (_paymentMethod) {
        case PaymentMethod.cash:
          methodStr = 'cash';
        case PaymentMethod.upi:
          methodStr = 'upi';
        case PaymentMethod.card:
          methodStr = 'card';
        case PaymentMethod.bankTransfer:
          methodStr = 'bank_transfer';
        case PaymentMethod.other:
          methodStr = 'other';
      }

      final yearText = _carYearController.text.trim();
      final result = await ref.read(createInvoiceServiceProvider).create(
            CreateInvoiceInput(
              businessId: business.id,
              customerName: _customerController.text.trim().isEmpty
                  ? null
                  : _customerController.text.trim(),
              customerMobile: _mobileController.text.trim().isEmpty
                  ? null
                  : _mobileController.text.trim(),
              items: _lines
                  .map(
                    (l) => CreateInvoiceLine(
                      description: l.description,
                      quantity: l.quantity.toDouble(),
                      unitPrice: l.unitPrice,
                      taxRate: l.taxRate,
                      discountAmount: l.discountAmount,
                      productVariantId: l.variantId,
                      size: l.size,
                      color: l.color,
                      barcode: l.barcode,
                    ),
                  )
                  .toList(),
              discountAmount: discount,
              additionalCharges: additional,
              notes: _emptyOr(_notesController),
              carMake: _emptyOr(_carMakeController),
              carModel: _emptyOr(_carModelController),
              carVariant: _emptyOr(_carVariantController),
              carRegistrationNumber: _emptyOr(_carRegistrationController),
              carChassisNumber: _emptyOr(_carChassisController),
              carEngineNumber: _emptyOr(_carEngineController),
              carManufacturingYear:
                  yearText.isEmpty ? null : int.tryParse(yearText),
              carColor: _emptyOr(_carColorController),
              carFuelType: _emptyOr(_carFuelController),
              initialPaymentAmount: payAmt,
              initialPaymentMethod: methodStr,
              autoWhatsapp: true,
            ),
          );

      if (!mounted) return;

      if (!result.success || result.invoiceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to create invoice')),
        );
        return;
      }

      final id = result.invoiceId!;
      var msg = 'Invoice created';
      if (result.whatsappSent == true) {
        msg = 'Invoice created · WhatsApp sent';
      } else if (result.whatsappSkipped != null) {
        msg = 'Invoice created · WhatsApp skipped';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          action: SnackBarAction(
            label: 'Print BT',
            onPressed: () {
              if (context.mounted) context.push('/invoices/$id?print=bt');
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      context.push('/invoices/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyOr(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  InputDecoration _fieldDeco({
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 1,
      isDense: true,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      filled: true,
      fillColor: AppColors.slate50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.brand(ref.read(activeBusinessProvider)?.businessType),
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final isClothing = business?.isClothing ?? false;
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final brandDark = AppColors.brandDark(business?.businessType);

    return AppScaffold(
      title: 'Create Invoice',
      // Always-visible Create button above bottom tabs.
      bottomBar: _CreateBar(
        brand: brand,
        totalLabel: _money.format(_grandTotal),
        saving: _saving,
        onCreate: _saving ? null : _createInvoice,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          Text(
            'New bill',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: brandDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            business?.name ?? 'Create invoice',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SoftSurface(
            elevated: true,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Customer', brand),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDeco(
                    label: 'Customer name',
                    hint: 'Name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDeco(
                    label: 'WhatsApp / Mobile',
                    hint: 'Optional',
                    icon: Icons.chat_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isClothing) ...[
            SoftSurface(
              elevated: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle('Scan barcode', brand),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text(
                      'Scan with camera',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualBarcodeController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _lookupManualBarcode(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          decoration: _fieldDeco(
                            label: 'Or type barcode',
                            hint: 'Barcode',
                            icon: Icons.qr_code_2_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: brandDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _lookingUpBarcode ? null : _lookupManualBarcode,
                          child: _lookingUpBarcode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Add',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_lastScanned != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastScanned!.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Sz ${_lastScanned!.size ?? '—'} · ${_lastScanned!.color ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _money.format(_lastScanned!.price),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: brandDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SoftSurface(
              elevated: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _SectionTitle('Items', brand)),
                      Text(
                        '${_lines.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_lines.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Text(
                        'Scan barcode to add items',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate500,
                        ),
                      ),
                    )
                  else
                    ..._lines.map(
                      (line) => _LineCard(
                        line: line,
                        brand: brand,
                        money: _money,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() => _lines.remove(line)),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            SoftSurface(
              elevated: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Vehicle', brand),
                  const SizedBox(height: 8),
                  _carField(_carMakeController, 'Make / Brand'),
                  const SizedBox(height: 8),
                  _carField(_carModelController, 'Model'),
                  const SizedBox(height: 8),
                  _carField(_carVariantController, 'Variant'),
                  const SizedBox(height: 8),
                  _carField(_carRegistrationController, 'Registration No.'),
                  const SizedBox(height: 8),
                  _carField(_carChassisController, 'Chassis No.'),
                  const SizedBox(height: 8),
                  _carField(_carEngineController, 'Engine No.'),
                  const SizedBox(height: 8),
                  _carField(
                    _carYearController,
                    'Year',
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _carField(_carColorController, 'Color'),
                  const SizedBox(height: 8),
                  _carField(_carFuelController, 'Fuel type'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SoftSurface(
            elevated: true,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _notesController,
              decoration: _fieldDeco(
                label: 'Notes',
                hint: 'Optional',
                icon: Icons.notes_rounded,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SoftSurface(
            elevated: true,
            padding: const EdgeInsets.all(12),
            borderColor: brand.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Totals', brand),
                const SizedBox(height: 8),
                _TotalRow('Subtotal', _money.format(_subtotal)),
                _TotalRow('Tax', _money.format(_tax)),
                const SizedBox(height: 8),
                TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDeco(label: 'Discount'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _additionalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDeco(label: 'Additional charges'),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brand.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'GRAND TOTAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: brandDark,
                          ),
                        ),
                      ),
                      Text(
                        _money.format(_grandTotal),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _paymentAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDeco(
                    label: 'Amount received',
                    hint: _money.format(_grandTotal),
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _paymentMethod,
                  decoration: _fieldDeco(
                    label: 'Payment method',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  items: PaymentMethod.values
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(Payment.label(m)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carField(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: _fieldDeco(label: label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.brand);
  final String text;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: brand,
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.brand,
    required this.money,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineItem line;
  final Color brand;
  final NumberFormat money;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
              ),
            ],
          ),
          if (line.barcode != null)
            Text(
              line.barcode!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.slate500,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (line.size != null && line.size!.isNotEmpty)
                _Chip(label: 'Size', value: line.size!),
              if (line.color != null && line.color!.isNotEmpty)
                _Chip(label: 'Color', value: line.color!),
              _Chip(
                label: 'Price',
                value: money.format(line.unitPrice),
                emphasize: true,
                color: brand,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyBtn(
                icon: Icons.remove_rounded,
                enabled: line.quantity > 1,
                brand: brand,
                onTap: () {
                  line.quantity--;
                  onChanged();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '${line.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _QtyBtn(
                icon: Icons.add_rounded,
                enabled: true,
                brand: brand,
                onTap: () {
                  line.quantity++;
                  onChanged();
                },
              ),
              const Spacer(),
              Text(
                money.format(line.lineTotal),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.slate800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasize ? accent.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasize
              ? accent.withValues(alpha: 0.3)
              : AppColors.slate200,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: emphasize ? accent : AppColors.slate500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: emphasize ? accent : AppColors.slate900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
    required this.icon,
    required this.enabled,
    required this.brand,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Color brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? brand.withValues(alpha: 0.12) : AppColors.slate100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? brand : AppColors.slate300,
          ),
        ),
      ),
    );
  }
}

class _CreateBar extends StatelessWidget {
  const _CreateBar({
    required this.brand,
    required this.totalLabel,
    required this.onCreate,
    this.saving = false,
  });

  final Color brand;
  final String totalLabel;
  final VoidCallback? onCreate;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate500,
                    ),
                  ),
                  Text(
                    totalLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: brand,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(148, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onCreate,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create invoice',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
