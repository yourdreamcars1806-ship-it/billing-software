import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/business.dart';
import '../models/invoice.dart';
import '../shared/widgets/business_logo.dart';
import '../theme/app_colors.dart';

/// 80mm thermal receipt — same look as web `DD-*-receipt.pdf`
/// (logo → barcode → shop/address → bill → items → totals).
class PdfInvoiceService {
  static const _carsAsset = 'assets/images/your-dream-cars-logo.png';

  Future<pw.ImageProvider?> _loadLogo(Business business) async {
    try {
      final url = business.logoUrl?.trim();
      if (url != null &&
          url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        return await networkImage(url);
      }

      if (business.isClothing || business.slug == 'drape-and-dream') {
        final data = await rootBundle.load(BusinessLogo.drapeAsset);
        return pw.MemoryImage(data.buffer.asUint8List());
      }
      if (business.isCar || business.slug == 'your-dream-cars') {
        final data = await rootBundle.load(_carsAsset);
        return pw.MemoryImage(data.buffer.asUint8List());
      }
    } catch (_) {}
    return null;
  }

  pw.Widget _barcode(String code, {double width = 150, double height = 38}) {
    return pw.Center(
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.code128(),
        data: code,
        width: width,
        height: height,
        drawText: true,
        textStyle: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  Future<pw.Document> buildReceiptDocument({
    required Business business,
    required Invoice invoice,
    String? customerName,
    String? customerMobile,
  }) async {
    final doc = pw.Document();
    // Match web @page 80mm × 140mm short pages (no bottom cut on printers).
    final roll = PdfPageFormat(
      80 * PdfPageFormat.mm,
      140 * PdfPageFormat.mm,
      marginAll: 2.5 * PdfPageFormat.mm,
    );

    final status = paymentStatusLabel(
      invoice.paymentStatus.name,
      businessType: business.businessType,
    );
    final isCar = business.isCar;
    final paidLabel = isCar ? 'Paid / Token' : 'Paid';
    final customer = (customerName?.trim().isNotEmpty == true)
        ? customerName!.trim()
        : (invoice.customer?.name.trim().isNotEmpty == true
            ? invoice.customer!.name
            : 'Walk-in');
    final mobile = (customerMobile?.trim().isNotEmpty == true)
        ? customerMobile!.trim()
        : (invoice.customer?.mobile != null &&
                invoice.customer!.mobile!.trim().isNotEmpty
            ? invoice.customer!.mobile!
            : '—');

    final logo = await _loadLogo(business);

    final purchasedCodes = <String>{
      for (final item in invoice.items)
        if (item.barcode != null && item.barcode!.trim().isNotEmpty)
          item.barcode!.trim(),
    }.toList();
    final singleBarcode =
        !isCar && purchasedCodes.length == 1 ? purchasedCodes.first : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: roll,
        maxPages: 40,
        footer: (context) {
          if (context.pageNumber >= context.pagesCount) {
            return pw.SizedBox();
          }
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Center(
              child: pw.Text(
                '…continued!',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          );
        },
        build: (context) {
          return [
            // —— Header: logo + barcode (web slip) ——
            if (logo != null) ...[
              pw.Center(
                child: pw.SizedBox(
                  width: 58 * PdfPageFormat.mm,
                  height: 26 * PdfPageFormat.mm,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 2),
            ],
            if (singleBarcode != null) ...[
              _barcode(singleBarcode),
              pw.SizedBox(height: 2),
            ],
            pw.Center(
              child: pw.Text(
                business.name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (business.address != null &&
                business.address!.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(
                  business.address!.trim(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                    lineSpacing: 1.2,
                  ),
                ),
              ),
            if (business.phone != null && business.phone!.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'Ph: ${business.phone!.trim()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            if (business.gstin != null && business.gstin!.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'GSTIN: ${business.gstin!.trim()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            if (business.pan != null && business.pan!.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(
                  'PAN: ${business.pan!.trim()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                ),
              ),

            pw.SizedBox(height: 3),
            _dash(),
            _kv('Bill No', invoice.invoiceNumber),
            _kv('Date', AppDateUtils.formatDate(invoice.invoiceDate)),
            _kv('Customer', customer),
            _kv('Mobile', mobile),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.9),
                ),
                child: pw.Text(
                  status.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (isCar) ...[
              pw.SizedBox(height: 3),
              _dash(),
              pw.Center(
                child: pw.Text(
                  'VEHICLE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (invoice.carMake != null || invoice.carModel != null)
                _kv(
                  'Make/Model',
                  [
                    invoice.carMake,
                    invoice.carModel,
                    invoice.carVariant,
                  ].whereType<String>().join(' '),
                ),
              if (invoice.carRegistrationNumber != null)
                _kv('Reg. No', invoice.carRegistrationNumber!),
              if (invoice.carColor != null) _kv('Color', invoice.carColor!),
              if (invoice.carFuelType != null)
                _kv('Fuel', invoice.carFuelType!),
              if (invoice.carChassisNumber != null)
                _kv('Chassis', invoice.carChassisNumber!),
              if (invoice.carEngineNumber != null)
                _kv('Engine', invoice.carEngineNumber!),
              if (invoice.carManufacturingYear != null)
                _kv('Year', '${invoice.carManufacturingYear}'),
            ],

            pw.SizedBox(height: 3),
            _dash(),
            pw.Center(
              child: pw.Text(
                'ITEMS',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (invoice.items.isEmpty)
              pw.Center(
                child: pw.Text(
                  isCar ? 'Vehicle billing' : 'No items',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              )
            else
              ...invoice.items.map((item) {
                final meta = !isCar
                    ? [
                        if (item.size != null && item.size!.isNotEmpty)
                          'Size ${item.size}',
                        if (item.color != null && item.color!.isNotEmpty)
                          'Color ${item.color}',
                      ].join(' · ')
                    : '';
                final code = !isCar ? (item.barcode?.trim() ?? '') : '';
                final showLineBarcode =
                    code.isNotEmpty && singleBarcode == null;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.description,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        pw.Text(
                          meta,
                          style: const pw.TextStyle(
                            fontSize: 7.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                      if (showLineBarcode) ...[
                        pw.SizedBox(height: 2),
                        _barcode(code, width: 140, height: 32),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.quantity} x ${CurrencyUtils.format(item.unitPrice)}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            CurrencyUtils.format(item.lineTotal),
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            pw.SizedBox(height: 3),
            _dash(),
            _moneyRow('Subtotal', invoice.subtotal),
            _moneyRow('Tax', invoice.taxAmount),
            if (invoice.discountAmount > 0)
              _moneyRow('Discount', invoice.discountAmount),
            if (invoice.additionalCharges > 0)
              _moneyRow('Other', invoice.additionalCharges),
            _moneyRow('TOTAL', invoice.grandTotal, bold: true),
            _moneyRow(paidLabel, invoice.amountPaid),
            _moneyRow('Balance', invoice.amountOutstanding),

            pw.SizedBox(height: 3),
            _dash(),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Thank you · Visit again',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                business.name,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return doc;
  }

  Future<void> printInvoice({
    required Business business,
    required Invoice invoice,
    String? customerName,
    String? customerMobile,
  }) async {
    final doc = await buildReceiptDocument(
      business: business,
      invoice: invoice,
      customerName: customerName,
      customerMobile: customerMobile,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: '${invoice.invoiceNumber}-receipt',
    );
  }

  Future<void> downloadInvoice({
    required Business business,
    required Invoice invoice,
    String? customerName,
    String? customerMobile,
  }) async {
    final doc = await buildReceiptDocument(
      business: business,
      invoice: invoice,
      customerName: customerName,
      customerMobile: customerMobile,
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${invoice.invoiceNumber}-receipt.pdf',
    );
  }

  pw.Widget _dash() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Text(
          '- - - - - - - - - - - - - - - - - -',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8, letterSpacing: 0.4),
        ),
      );

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 52,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _moneyRow(String label, num amount, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 11 : 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(CurrencyUtils.format(amount), style: style),
        ],
      ),
    );
  }
}
