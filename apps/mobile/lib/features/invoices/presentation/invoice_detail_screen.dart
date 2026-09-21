import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/invoice.dart';
import '../../../models/payment.dart';
import '../../../repositories/invoice_repository.dart';
import '../../../services/bluetooth_printer_service.dart';
import '../../../services/create_invoice_service.dart';
import '../../../services/escpos_receipt_builder.dart';
import '../../../services/pdf_invoice_service.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../../payments/presentation/add_payment_sheet.dart';
import '../providers/invoices_provider.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.autoPrintBt = false,
  });

  final String invoiceId;
  final bool autoPrintBt;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _printing = false;
  bool _deleting = false;
  bool _whatsapping = false;
  bool _autoPrintDone = false;
  String _busyMessage = 'Preparing PDF…';
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    if (widget.autoPrintBt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_autoPrintDone && mounted) {
          _autoPrintDone = true;
          _printBluetooth();
        }
      });
    }
  }

  Future<void> _printMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download receipt'),
                  subtitle: const Text('Save / share 80mm PDF'),
                  onTap: () => Navigator.pop(ctx, 'download'),
                ),
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('Bluetooth thermal printer'),
                  subtitle: const Text('80mm ESC/POS slip'),
                  onTap: () => Navigator.pop(ctx, 'bt'),
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('System print'),
                  subtitle: const Text('Phone print dialog'),
                  onTap: () => Navigator.pop(ctx, 'pdf'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == 'download') {
      await _downloadPdf();
    } else if (choice == 'bt') {
      await _printBluetooth();
    } else if (choice == 'pdf') {
      await _printPdf();
    }
  }

  Future<void> _downloadPdf() async {
    final business = ref.read(activeBusinessProvider);
    setState(() {
      _printing = true;
      _busyMessage = 'Preparing download…';
    });
    try {
      final invoice =
          await ref.read(invoiceProvider(widget.invoiceId).future);
      if (invoice == null || business == null) return;
      await PdfInvoiceService().downloadInvoice(
        business: business,
        invoice: invoice,
        customerName: invoice.customer?.name,
        customerMobile: invoice.customer?.mobile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt ready · ${invoice.invoiceNumber}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printPdf() async {
    final business = ref.read(activeBusinessProvider);
    setState(() {
      _printing = true;
      _busyMessage = 'Preparing PDF…';
    });
    try {
      final invoice =
          await ref.read(invoiceProvider(widget.invoiceId).future);
      if (invoice == null || business == null) return;
      await PdfInvoiceService().printInvoice(
        business: business,
        invoice: invoice,
        customerName: invoice.customer?.name,
        customerMobile: invoice.customer?.mobile,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printBluetooth() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    setState(() {
      _printing = true;
      _busyMessage = 'Printing via Bluetooth…';
    });
    try {
      final invoice =
          await ref.read(invoiceProvider(widget.invoiceId).future);
      if (invoice == null) return;

      final customerName = invoice.customer?.name;
      final customerMobile = invoice.customer?.mobile;

      final svc = ref.read(bluetoothPrinterServiceProvider);
      await svc.loadSavedPrinter();
      if (svc.savedMac == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Select a Bluetooth printer in Settings → Bluetooth printer',
            ),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => context.push('/settings/bluetooth-printer'),
            ),
          ),
        );
        return;
      }

      final bytes = await svc.buildInvoiceBytes(
        EscPosReceiptData(
          business: business,
          invoice: invoice,
          customerName: customerName,
          customerMobile: customerMobile,
          items: invoice.items,
        ),
      );
      await svc.printReceipt(bytes: bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printed · ${invoice.invoiceNumber}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _sendWhatsapp() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;
    final invoice = await ref.read(invoiceProvider(widget.invoiceId).future);
    if (invoice == null || !mounted) return;

    final mobile = invoice.customer?.mobile?.trim() ?? '';
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No customer mobile on this bill — WhatsApp skipped'),
        ),
      );
      return;
    }

    setState(() => _whatsapping = true);
    try {
      final result = await ref
          .read(createInvoiceServiceProvider)
          .sendWhatsappInvoice(
            businessId: business.id,
            invoiceId: invoice.id,
            customerMobile: mobile,
          );
      if (!mounted) return;
      if (result.$1 == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp invoice sent')),
        );
      } else if (result.$2 != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp skipped: ${result.$2}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.$3 ?? 'WhatsApp failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _whatsapping = false);
    }
  }

  Future<void> _delete() async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    final invoice = await ref.read(invoiceProvider(widget.invoiceId).future);
    if (invoice == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Delete ${invoice.invoiceNumber}? It will be removed from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .deleteInvoice(business.id, invoice.id);
      ref.invalidate(invoicesProvider);
      if (mounted) popOrFallback(context, fallback: '/invoices');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(invoiceProvider(widget.invoiceId));
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final soft = AppColors.brandSoft(business?.businessType);
    final busy = _printing || _deleting || _whatsapping;

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.bg,
          drawer: AppDrawer(currentPath: '/invoices/${widget.invoiceId}'),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: 96,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                  onPressed: () =>
                      popOrFallback(context, fallback: '/invoices'),
                ),
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  onPressed: () {
                    final s = _scaffoldKey.currentState;
                    if (s == null) return;
                    if (s.isDrawerOpen) {
                      s.closeDrawer();
                    } else {
                      s.openDrawer();
                    }
                  },
                ),
              ],
            ),
            title: const Text('Invoice Details'),
            actions: [
              IconButton(
                tooltip: 'Download',
                style: IconButton.styleFrom(
                  backgroundColor: brand.withValues(alpha: 0.08),
                ),
                icon: Icon(Icons.download_rounded, color: brand, size: 20),
                onPressed: busy ? null : _downloadPdf,
              ),
              IconButton(
                tooltip: 'WhatsApp',
                style: IconButton.styleFrom(
                  backgroundColor: brand.withValues(alpha: 0.08),
                ),
                icon: _whatsapping
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: brand,
                        ),
                      )
                    : Icon(Icons.chat_outlined, color: brand, size: 20),
                onPressed: busy ? null : _sendWhatsapp,
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                ),
                icon: _deleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: busy ? null : _delete,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: brand.withValues(alpha: 0.1),
                  ),
                  icon: _printing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: brand,
                          ),
                        )
                      : Icon(Icons.print_outlined, color: brand, size: 20),
                  onPressed: busy ? null : _printMenu,
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.slate200),
            ),
          ),
          body: invoiceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (invoice) {
              if (invoice == null) {
                return const Center(child: Text('Invoice not found'));
              }

              final statusColor = switch (invoice.paymentStatus) {
                PaymentStatus.paid => AppColors.success,
                PaymentStatus.partial => AppColors.warning,
                PaymentStatus.pending => AppColors.error,
              };
              final statusLabel = paymentStatusLabel(
                invoice.paymentStatus.name,
                businessType: business?.businessType,
              );
              final customerName = invoice.customer?.name;
              final customerMobile = invoice.customer?.mobile;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  PageHero(
                    title: invoice.invoiceNumber,
                    subtitle: AppDateUtils.formatDate(invoice.invoiceDate),
                    icon: Icons.receipt_long,
                    brand: brand,
                    soft: soft,
                    trailing:
                        StatusBadge(label: statusLabel, color: statusColor),
                  ),
                  if (customerName != null || customerMobile != null) ...[
                    const SizedBox(height: 12),
                    SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Customer'),
                          const SizedBox(height: 10),
                          if (customerName != null && customerName.isNotEmpty)
                            _DetailRow('Name', customerName),
                          if (customerMobile != null &&
                              customerMobile.isNotEmpty)
                            _DetailRow('Mobile', customerMobile),
                        ],
                      ),
                    ),
                  ],
                  if (invoice.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Line items'),
                          const SizedBox(height: 10),
                          ...invoice.items.map((item) {
                            final meta = [
                              if (item.size != null && item.size!.isNotEmpty)
                                'Size ${item.size}',
                              if (item.color != null && item.color!.isNotEmpty)
                                'Color ${item.color}',
                            ].join(' · ');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        CurrencyUtils.format(item.lineTotal),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: brand,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (meta.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        meta,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${item.quantity} × ${CurrencyUtils.format(item.unitPrice)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SoftSurface(
                    child: Column(
                      children: [
                        _DetailRow(
                          'Subtotal',
                          CurrencyUtils.format(invoice.subtotal),
                        ),
                        _DetailRow(
                          'Tax',
                          CurrencyUtils.format(invoice.taxAmount),
                        ),
                        _DetailRow(
                          'Discount',
                          CurrencyUtils.format(invoice.discountAmount),
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          'Grand Total',
                          CurrencyUtils.format(invoice.grandTotal),
                          isBold: true,
                          color: brand,
                        ),
                        _DetailRow(
                          'Paid',
                          CurrencyUtils.format(invoice.amountPaid),
                          color: AppColors.success,
                        ),
                        _DetailRow(
                          'Outstanding',
                          CurrencyUtils.format(invoice.amountOutstanding),
                          color: invoice.amountOutstanding > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  if (invoice.payments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Payments'),
                          const SizedBox(height: 10),
                          ...invoice.payments.map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Payment.label(p.paymentMethod),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          AppDateUtils.formatDate(
                                            p.paymentDate,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.slate500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyUtils.format(p.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  if (invoice.isCarInvoice) ...[
                    const SizedBox(height: 12),
                    SoftSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconBadge(
                                icon: Icons.directions_car,
                                color: brand,
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Vehicle details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: brand,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (invoice.carMake != null)
                            _DetailRow('Make', invoice.carMake!),
                          if (invoice.carModel != null)
                            _DetailRow('Model', invoice.carModel!),
                          if (invoice.carRegistrationNumber != null)
                            _DetailRow(
                              'Registration',
                              invoice.carRegistrationNumber!,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SoftSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: busy ? null : _downloadPdf,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download receipt'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _printMenu,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print / Bluetooth'),
                        ),
                      ],
                    ),
                  ),
                  if (invoice.amountOutstanding > 0) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                                builder: (_) =>
                                    AddPaymentSheet(invoice: invoice),
                              ).then(
                                (_) => ref.invalidate(
                                  invoiceProvider(widget.invoiceId),
                                ),
                              ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        business?.isCar == true
                            ? 'Add Token / Payment'
                            : 'Add Payment',
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        LoadingOverlay(
          isVisible: busy,
          message: _deleting
              ? 'Deleting…'
              : _whatsapping
                  ? 'Sending WhatsApp…'
                  : _busyMessage,
        ),
      ],
    );
  }
}

extension on Invoice {
  bool get isCarInvoice =>
      carMake != null || carModel != null || carRegistrationNumber != null;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isBold = false, this.color});

  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.slate600,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color ?? AppColors.slate800,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
