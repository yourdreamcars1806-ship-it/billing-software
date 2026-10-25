import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_utils.dart';
import '../models/business.dart';
import '../models/delivery_note.dart';
import '../shared/widgets/business_logo.dart';

/// A4 Vehicle Delivery Note — same layout/sections as web `delivery-note-document.ts`.
class PdfDeliveryNoteService {
  static const _carsAsset = 'assets/images/your-dream-cars-logo.png';
  static const _navy = PdfColor.fromInt(0xFF0B1F4D);
  static const _ink = PdfColor.fromInt(0xFF111111);
  static const _muted = PdfColor.fromInt(0xFF555555);
  static const _line = PdfColor.fromInt(0xFF1A1A1A);
  static const _green = PdfColor.fromInt(0xFF166534);
  static const _red = PdfColor.fromInt(0xFF991B1B);

  Future<pw.ImageProvider?> _loadLogo(Business business) async {
    try {
      final url = business.logoUrl?.trim();
      if (url != null &&
          url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        return await networkImage(url);
      }
      final data = await rootBundle.load(
        business.isClothing ? BusinessLogo.drapeAsset : _carsAsset,
      );
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}
    return null;
  }

  String _blank(String value, [String blank = '____________________']) {
    final v = value.trim();
    return v.isEmpty ? blank : v;
  }

  String _money(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 'Rs. ____________________';
    final n = double.tryParse(cleaned);
    if (n == null) return 'Rs. ____________________';
    return CurrencyUtils.format(n);
  }

  String _displayDate(String iso) {
    final t = iso.trim();
    if (t.isEmpty) return '____ / ____ / ______';
    final d = DateTime.tryParse(t.contains('T') ? t : '${t}T12:00:00');
    if (d == null) return t;
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _box(bool on) => on ? '☑' : '☐';

  Future<pw.Document> buildDocument({
    required Business business,
    required DeliveryNoteFormData data,
  }) async {
    final doc = pw.Document();
    final logo = await _loadLogo(business);
    final name = business.name.trim().isEmpty
        ? 'Your Dream Cars'
        : business.name.trim();
    final address = (business.address?.trim().isNotEmpty == true)
        ? business.address!.trim()
        : 'Clover Hills Plaza, NIBM, Pune';
    final phone = business.phone?.trim() ?? '';
    final email = business.email?.trim() ?? '';
    final status = data.deliveryStatus.trim().isEmpty
        ? 'draft'
        : data.deliveryStatus.trim();
    final statusLabel = status == 'confirmed'
        ? 'CONFIRMED'
        : status == 'cancelled'
            ? 'CANCELLED'
            : 'DRAFT';
    final statusColor = status == 'confirmed'
        ? _green
        : status == 'cancelled'
            ? _red
            : _navy;

    final declName = data.declarationName.trim().isNotEmpty
        ? data.declarationName.trim()
        : (data.customerName.trim().isNotEmpty
            ? data.customerName.trim()
            : '____________________');

    final cancelText = data.cancellationTerms.trim().isNotEmpty
        ? data.cancellationTerms.trim()
        : DeliveryNoteFormData.defaultCancellationTerms(
            gstPercent: data.cancelGstPercent,
            paperFee: data.paperProcessingFee,
            businessName: name,
          );
    final gstLabel =
        data.cancelGstPercent.trim().isEmpty ? '18' : data.cancelGstPercent.trim();
    final feeLabel = data.paperProcessingFee.trim().isNotEmpty
        ? CurrencyUtils.format(double.tryParse(data.paperProcessingFee) ?? 0)
        : 'As applicable';

    final payRow = [
      '${_box(data.paymentModes.cash)} Cash',
      '${_box(data.paymentModes.upi)} UPI',
      '${_box(data.paymentModes.bankTransfer)} Bank Transfer',
      '${_box(data.paymentModes.finance)} Finance',
      '${_box(data.paymentModes.other)} Other${data.paymentOther.trim().isNotEmpty ? ' (${data.paymentOther.trim()})' : ''}',
    ].join('   ');

    final docRow = [
      '${_box(data.docs.rc)} RC',
      '${_box(data.docs.insurance)} Insurance',
      '${_box(data.docs.puc)} PUC',
      '${_box(data.docs.serviceRecords)} Service Records',
      '${_box(data.docs.keys)} Keys',
      '${_box(data.docs.spareKey)} Spare Key',
      '${_box(data.docs.other)} Other${data.docsOther.trim().isNotEmpty ? ' (${data.docsOther.trim()})' : ''}',
    ].join('   ');

    final idCombo = [
      data.idProof.trim(),
      data.idNo.trim(),
    ].where((x) => x.isNotEmpty).join(' / ');

    final signDate = data.customerSignDatetime.trim().isNotEmpty
        ? data.customerSignDatetime.trim()
        : [
            _displayDate(data.deliveryDate),
            data.deliveryTime.trim(),
          ].where((x) => x.isNotEmpty && !x.contains('____')).join(' · ');

    // Devanagari for Marathi warranty lines (Helvetica cannot draw those glyphs).
    pw.Font? mrFont;
    pw.Font? mrBold;
    try {
      mrFont = await PdfGoogleFonts.notoSansDevanagariRegular();
      mrBold = await PdfGoogleFonts.notoSansDevanagariBold();
    } catch (_) {
      try {
        mrFont = await PdfGoogleFonts.notoSansRegular();
        mrBold = await PdfGoogleFonts.notoSansBold();
      } catch (_) {}
    }

    final warrantyBox = _warrantyBox(marathi: mrFont, marathiBold: mrBold);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        build: (context) {
          return [
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line, width: 2),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: const PdfColor.fromInt(0xFF444444),
                    width: 1,
                  ),
                ),
                padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Letterhead
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logo != null)
                          pw.SizedBox(
                            width: 58,
                            height: 58,
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(width: 58, height: 58),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              pw.Text(
                                name.toUpperCase(),
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _navy,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                address,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColor.fromInt(0xFF333333),
                                ),
                              ),
                              if (phone.isNotEmpty || email.isNotEmpty)
                                pw.Text(
                                  [
                                    if (phone.isNotEmpty) 'Tel: $phone',
                                    if (email.isNotEmpty) 'Email: $email',
                                  ].join('  |  '),
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(
                                    fontSize: 8.5,
                                    color: _muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          width: 72,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: statusColor, width: 1.5),
                          ),
                          child: pw.Text(
                            statusLabel,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(height: 1.5, color: _line),

                    if (status == 'cancelled') ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _red, width: 2),
                        ),
                        child: pw.Text(
                          data.cancelReason.trim().isNotEmpty
                              ? 'DEAL / DELIVERY CANCELLED — ${data.cancelReason.trim()}'
                              : 'DEAL / DELIVERY CANCELLED',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _red,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],

                    pw.SizedBox(height: 10),
                    pw.Text(
                      'VEHICLE DELIVERY NOTE',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.2,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Official handover record · Keep two signed copies',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                    ),
                    pw.SizedBox(height: 10),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _meta('Delivery Note No.:', _blank(data.deliveryNoteNo)),
                        _meta('Date:', _displayDate(data.deliveryDate)),
                        _meta('Time:', _blank(data.deliveryTime, '____________')),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    _sectionTitle('1. Customer Details'),
                    _field('Customer Name', _blank(data.customerName)),
                    _field('Address', _blank(data.customerAddress)),
                    _field('Mobile No.', _blank(data.customerMobile)),
                    _field('ID Proof / ID No.', _blank(idCombo)),

                    _sectionTitle('2. Vehicle Details'),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              _field('Make / Brand', _blank(data.carMake)),
                              _field(
                                'Registration No.',
                                _blank(data.carRegistrationNumber),
                              ),
                              _field('Colour', _blank(data.carColor)),
                              _field(
                                'Chassis No.',
                                _blank(data.carChassisNumber),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              _field(
                                'Model / Variant',
                                _blank(data.carModelVariant),
                              ),
                              _field(
                                'Year of Manufacture',
                                _blank(data.carManufacturingYear),
                              ),
                              _field('Fuel Type', _blank(data.carFuelType)),
                              _field(
                                'Engine No.',
                                _blank(data.carEngineNumber),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _field(
                      'Odometer Reading',
                      data.odometerKm.trim().isEmpty
                          ? '____________________ KM'
                          : '${data.odometerKm.trim()} KM',
                    ),

                    _sectionTitle('3. Payment Details'),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              _field(
                                'Total Vehicle Price',
                                _money(data.totalVehiclePrice),
                              ),
                              _field(
                                'Balance Amount',
                                _money(data.balanceAmount),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              _field(
                                'Amount Received',
                                _money(data.amountReceived),
                              ),
                              _field('Payment Mode', payRow, boldValue: false),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _sectionTitle('4. Documents / Items Handed Over'),
                    pw.Text(
                      docRow,
                      style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                    ),

                    _sectionTitle('5. Delivery Declaration'),
                    pw.Text(
                      'I, $declName, confirm that I have inspected the above-mentioned vehicle '
                      'and have taken physical delivery of it from $name '
                      'in the condition mutually agreed upon.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 9.5, color: _ink),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'I acknowledge receipt of the vehicle, keys and documents/items mentioned above. '
                      'Any pending documentation, ownership transfer, payment or other commitment, if applicable, '
                      'shall be completed according to the separately agreed terms.',
                      textAlign: pw.TextAlign.justify,
                      style: const pw.TextStyle(fontSize: 9.5, color: _ink),
                    ),
                    pw.SizedBox(height: 8),
                    warrantyBox,
                    pw.SizedBox(height: 10),

                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: _signBox(
                            title: 'Customer Signature',
                            lines: [
                              'Name: ${_blank(data.customerSignName.trim().isNotEmpty ? data.customerSignName : data.customerName)}',
                              'Date & Time: ${_blank(signDate)}',
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: _signBox(
                            title: 'For ${name.toUpperCase()}',
                            lines: [
                              'Authorized Signature / Stamp',
                              'Name: ${_blank(data.authSignName)}',
                              'Handed Over By: ${_blank(data.handedOverBy)}',
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (data.cancelTermsEnabled) ...[
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFFAFAFA),
                          border: pw.Border.all(
                            color: const PdfColor.fromInt(0xFF333333),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '7. DEAL CANCELLATION CHARGES',
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'GST on cancellation: $gstLabel%  |  Paper processing fees: $feeLabel',
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              cancelText,
                              textAlign: pw.TextAlign.justify,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    pw.SizedBox(height: 10),
                    pw.Container(height: 1, color: const PdfColor.fromInt(0xFF999999)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'This delivery note supplements (does not replace) the sale agreement / receipt and RTO transfer documents. '
                      '· Customer copy & dealer copy to be signed. '
                      '· ${data.deliveryNoteNo}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromInt(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return doc;
  }

  pw.Widget _meta(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _warrantyBox({pw.Font? marathi, pw.Font? marathiBold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F7F7),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFF333333)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '6. ENGINE WARRANTY',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '3 Months Engine Warranty or 5000 KM (Whichever Comes First)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Only for engine warranty, not for electrical parts. T&C apply.',
            style: const pw.TextStyle(fontSize: 9.5, color: _ink),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '३ महिने इंजिन वॉरंटी किंवा ५००० किलोमीटर (जे आधी होईल ते).',
            style: pw.TextStyle(
              font: marathiBold ?? marathi,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'इलेक्ट्रिकल पार्ट्ससाठी वॉरंटी नाही असे आणि अटी लागू.',
            style: pw.TextStyle(
              font: marathi,
              fontSize: 9.5,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(height: 1, color: _line),
        ],
      ),
    );
  }

  pw.Widget _field(String label, String value, {bool boldValue = true}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 118,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
          ),
          pw.Text(' : ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(left: 4, bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF666666),
                    width: 0.6,
                    style: pw.BorderStyle.dotted,
                  ),
                ),
              ),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      boldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _signBox({required String title, required List<String> lines}) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 108),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFF333333)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 28),
          for (final line in lines) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColor.fromInt(0xFF333333)),
                ),
              ),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> sharePdf({
    required Business business,
    required DeliveryNoteFormData data,
  }) async {
    final doc = await buildDocument(business: business, data: data);
    final bytes = await doc.save();
    final no = data.deliveryNoteNo.trim().isEmpty
        ? 'delivery-note'
        : data.deliveryNoteNo.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    await Printing.sharePdf(bytes: bytes, filename: '$no.pdf');
  }

  Future<void> printPdf({
    required Business business,
    required DeliveryNoteFormData data,
  }) async {
    final doc = await buildDocument(business: business, data: data);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
