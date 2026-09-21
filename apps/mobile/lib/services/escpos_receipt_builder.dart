import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/business.dart';
import '../models/invoice.dart';
import '../theme/app_colors.dart';

class EscPosReceiptData {
  const EscPosReceiptData({
    required this.business,
    required this.invoice,
    this.customerName,
    this.customerMobile,
    this.items = const [],
  });

  final Business business;
  final Invoice invoice;
  final String? customerName;
  final String? customerMobile;
  final List<InvoiceItem> items;
}

/// 80mm ESC/POS slip — matches web thermal rules (address + customer, no GST/PAN/office phone).
class EscPosReceiptBuilder {
  Future<List<int>> build(EscPosReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    final business = data.business;
    final invoice = data.invoice;
    final isCar = business.isCar;
    final status = paymentStatusLabel(
      invoice.paymentStatus.name,
      businessType: business.businessType,
    );
    final paidLabel = isCar ? 'Paid / Token' : 'Paid';
    final customer = (data.customerName?.trim().isNotEmpty == true)
        ? data.customerName!.trim()
        : 'Walk-in';
    final mobile = (data.customerMobile?.trim().isNotEmpty == true)
        ? data.customerMobile!.trim()
        : '—';

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        business.name.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    );

    if (business.address != null && business.address!.trim().isNotEmpty) {
      bytes.addAll(
        generator.text(
          business.address!.trim(),
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }

    bytes.addAll(generator.hr());
    bytes.addAll(_kv(generator, 'Bill No', invoice.invoiceNumber));
    bytes.addAll(
      _kv(generator, 'Date', AppDateUtils.formatDate(invoice.invoiceDate)),
    );
    bytes.addAll(_kv(generator, 'Customer', customer));
    bytes.addAll(_kv(generator, 'Mobile', mobile));
    bytes.addAll(
      generator.text(
        status.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    if (isCar) {
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          'VEHICLE',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      final makeModel = [
        invoice.carMake,
        invoice.carModel,
        invoice.carVariant,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      if (makeModel.isNotEmpty) {
        bytes.addAll(_kv(generator, 'Make/Model', makeModel));
      }
      if (invoice.carRegistrationNumber != null) {
        bytes.addAll(_kv(generator, 'Reg. No', invoice.carRegistrationNumber!));
      }
      if (invoice.carColor != null) {
        bytes.addAll(_kv(generator, 'Color', invoice.carColor!));
      }
      if (invoice.carFuelType != null) {
        bytes.addAll(_kv(generator, 'Fuel', invoice.carFuelType!));
      }
    }

    final lineItems =
        data.items.isNotEmpty ? data.items : invoice.items;
    if (lineItems.isNotEmpty) {
      bytes.addAll(generator.hr());
      bytes.addAll(
        generator.text(
          'ITEMS',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      for (final item in lineItems) {
        final meta = [
          if (item.size != null && item.size!.trim().isNotEmpty)
            'Sz ${item.size}',
          if (item.color != null && item.color!.trim().isNotEmpty)
            item.color!,
        ].join(' · ');
        bytes.addAll(
          generator.text(
            item.description,
            styles: const PosStyles(bold: true),
          ),
        );
        if (meta.isNotEmpty) {
          bytes.addAll(generator.text(meta));
        }
        final qtyPrice =
            '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} x ${CurrencyUtils.format(item.unitPrice)}';
        bytes.addAll(
          _kv(generator, qtyPrice, CurrencyUtils.format(item.lineTotal)),
        );
      }
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      _kv(
        generator,
        'TOTAL',
        CurrencyUtils.format(invoice.grandTotal),
        bold: true,
      ),
    );
    bytes.addAll(
      _kv(generator, paidLabel, CurrencyUtils.format(invoice.amountPaid)),
    );
    bytes.addAll(
      _kv(
        generator,
        'Balance',
        CurrencyUtils.format(invoice.amountOutstanding),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(
        'Thank you · Visit again',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        business.name,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  List<int> _kv(
    Generator generator,
    String label,
    String value, {
    bool bold = false,
  }) {
    return generator.row([
      PosColumn(
        text: label,
        width: 5,
        styles: PosStyles(bold: bold),
      ),
      PosColumn(
        text: value,
        width: 7,
        styles: PosStyles(align: PosAlign.right, bold: bold),
      ),
    ]);
  }
}
