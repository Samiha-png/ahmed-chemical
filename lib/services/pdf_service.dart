import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/purchase_order.dart';
import '../models/sales_invoice.dart';
import 'settings_service.dart';

class PdfService {
  // ─────────────────────────────────────────────────────────
  // PURCHASE ORDER
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> generatePurchaseOrder(
    PurchaseOrder po, {
    CompanySettings? settings,
    String? customSignatureUrl,
  }) async {
    final company = settings ?? CompanySettings.defaults();
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final dfmt = DateFormat('dd MMM yyyy');

    final logo = await _loadImage(company.logoUrl);
    final sigUrl = (customSignatureUrl != null &&
            customSignatureUrl.trim().isNotEmpty)
        ? customSignatureUrl
        : company.signatureUrl;
    final signature = await _loadImage(sigUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (ctx) => _footer(ctx, company),
        build: (ctx) => [
          _header(company, logo, 'PURCHASE ORDER', po.number,
              po.createdAt, dfmt),
          pw.SizedBox(height: 12),
          _infoBar([
            _InfoBlock('Supplier', po.supplierName, span: 2),
            _InfoBlock(
              'Expected Delivery',
              po.expectedDelivery == null
                  ? '—'
                  : dfmt.format(po.expectedDelivery!),
              span: 1,
              align: pw.TextAlign.right,
            ),
            _InfoBlock(
              'Currency',
              '${po.currency}  •  Rate ${po.exchangeRate}',
              span: 1,
              align: pw.TextAlign.right,
            ),
          ]),
          pw.SizedBox(height: 14),
          _linesTable(
            headers: const [
              '#', 'Product', 'SKU', 'Qty', 'Unit',
              'Rate', 'Disc', 'Tax', 'Amount',
            ],
            rows: List.generate(po.lines.length, (i) {
              final l = po.lines[i];
              return [
                '${i + 1}',
                l.productName,
                l.sku,
                l.quantity.toStringAsFixed(2),
                l.baseUnit,
                fmt.format(l.unitPrice),
                '${l.discountPercent}%',
                '${l.taxPercent}%',
                fmt.format(l.lineTotal),
              ];
            }),
            minHeight: 10,
          ),
          pw.SizedBox(height: 14),
          _totalsBox(
            currency: po.currency,
            lines: [
              ['Subtotal', fmt.format(po.subtotal)],
              ['Tax', fmt.format(po.taxTotal)],
              if (po.freight > 0) ['Freight', fmt.format(po.freight)],
              if (po.otherCharges > 0)
                ['Other Charges', fmt.format(po.otherCharges)],
            ],
            grandTotal: fmt.format(po.grandTotal),
            baseTotal:
                po.currency != 'PKR' ? fmt.format(po.baseTotal) : null,
          ),
          if (po.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _notesBox(po.notes),
          ],
          pw.SizedBox(height: 20),
          _signatureRow(signature,
              leftLabel: 'Prepared By', rightLabel: 'Approved By'),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  // SALES INVOICE
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> generateSalesInvoice(
    SalesInvoice inv, {
    CompanySettings? settings,
    String? customSignatureUrl,
  }) async {
    final company = settings ?? CompanySettings.defaults();
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final dfmt = DateFormat('dd MMM yyyy');

    final logo = await _loadImage(company.logoUrl);
    final sigUrl = (customSignatureUrl != null &&
            customSignatureUrl.trim().isNotEmpty)
        ? customSignatureUrl
        : company.signatureUrl;
    final signature = await _loadImage(sigUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (ctx) => _footer(ctx, company),
        build: (ctx) => [
          _header(company, logo, 'SALES INVOICE', inv.number,
              inv.invoiceDate ?? inv.createdAt, dfmt),
          pw.SizedBox(height: 12),
          _infoBar([
            _InfoBlock('Bill To', inv.customerName, span: 2),
            _InfoBlock(
              'Invoice Date',
              inv.invoiceDate == null
                  ? '—'
                  : dfmt.format(inv.invoiceDate!),
              span: 1,
              align: pw.TextAlign.right,
            ),
            _InfoBlock(
              'Due Date',
              inv.dueDate == null ? '—' : dfmt.format(inv.dueDate!),
              span: 1,
              align: pw.TextAlign.right,
            ),
          ]),
          pw.SizedBox(height: 14),
          _linesTable(
            headers: const [
              '#', 'Product', 'SKU', 'Qty', 'Unit',
              'Rate', 'Disc', 'Tax', 'Amount',
            ],
            rows: List.generate(inv.lines.length, (i) {
              final l = inv.lines[i];
              return [
                '${i + 1}',
                l.productName,
                l.sku,
                l.quantity.toStringAsFixed(2),
                l.baseUnit,
                fmt.format(l.unitPrice),
                '${l.discountPercent}%',
                '${l.taxPercent}%',
                fmt.format(l.lineTotal),
              ];
            }),
            minHeight: 10,
          ),
          pw.SizedBox(height: 14),
          _totalsBox(
            currency: inv.currency,
            lines: [
              ['Subtotal', fmt.format(inv.subtotal)],
              ['Tax', fmt.format(inv.taxTotal)],
              if (inv.freight > 0)
                ['Freight', fmt.format(inv.freight)],
              if (inv.otherCharges > 0)
                ['Other Charges', fmt.format(inv.otherCharges)],
              if (inv.amountPaid > 0)
                ['Paid', fmt.format(inv.amountPaid)],
            ],
            grandTotal: fmt.format(inv.grandTotal),
            baseTotal: inv.currency != 'PKR'
                ? fmt.format(inv.baseTotal)
                : null,
            outstanding: inv.amountPaid > 0
                ? fmt.format(inv.outstanding)
                : null,
          ),
          if (inv.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _notesBox(inv.notes),
          ],
          pw.SizedBox(height: 20),
          _signatureRow(signature,
              leftLabel: 'Received By',
              rightLabel: 'Authorized Signature'),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────
  // SHARED COMPONENTS
  // ─────────────────────────────────────────────────────────

  static pw.Widget _header(
    CompanySettings company,
    pw.ImageProvider? logo,
    String docTitle,
    String docNumber,
    DateTime? docDate,
    DateFormat dfmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green800, width: 1.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 54,
              height: 54,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.companyName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                if (company.address.isNotEmpty)
                  pw.Text(company.address,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey700)),
                pw.SizedBox(height: 1),
                pw.Wrap(
                  spacing: 10,
                  children: [
                    if (company.phone.isNotEmpty)
                      pw.Text('Phone: ${company.phone}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                    if (company.email.isNotEmpty)
                      pw.Text('Email: ${company.email}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                    if (company.taxNumber.isNotEmpty)
                      pw.Text('NTN: ${company.taxNumber}',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                docTitle,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                  letterSpacing: 0.6,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                docNumber,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                docDate == null ? '' : dfmt.format(docDate),
                style: const pw.TextStyle(
                    fontSize: 8.5, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoBar(List<_InfoBlock> blocks) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final b in blocks)
            pw.Expanded(
              flex: b.span,
              child: pw.Column(
                crossAxisAlignment: b.align == pw.TextAlign.right
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    b.label.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                      letterSpacing: 0.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    b.value,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: b.align,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Lines table — pads with empty rows so it appears "filled" even
  /// when there are only 1-2 items.
  static pw.Widget _linesTable({
    required List<String> headers,
    required List<List<String>> rows,
    int minHeight = 10,
  }) {
    final padded = List<List<String>>.from(rows);
    while (padded.length < minHeight) {
      padded.add(List.filled(headers.length, ''));
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: padded,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.5,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
    );
  }

  static pw.Widget _totalsBox({
    required String currency,
    required List<List<String>> lines,
    required String grandTotal,
    String? baseTotal,
    String? outstanding,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 250,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
          ),
          child: pw.Column(
            children: [
              for (final row in lines) _totRow(row[0], row[1]),
              pw.Divider(
                  color: PdfColors.grey400, height: 6, thickness: 0.5),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        )),
                    pw.Text('$currency $grandTotal',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        )),
                  ],
                ),
              ),
              if (baseTotal != null)
                _totRow('Base (PKR)', baseTotal, muted: true),
              if (outstanding != null) ...[
                pw.Divider(
                    color: PdfColors.grey400, height: 6, thickness: 0.5),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Outstanding',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          )),
                      pw.Text('$currency $outstanding',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _notesBox(String notes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  /// Signature row — bigger, bolder, thicker lines for a premium look.
  static pw.Widget _signatureRow(
    pw.ImageProvider? signature, {
    required String leftLabel,
    required String rightLabel,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Left signature box
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 220,
              height: 50,
              alignment: pw.Alignment.bottomCenter,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey700, width: 0.8),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(leftLabel,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
        // Right signature box (with image if available)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 240,
              height: 60,
              alignment: pw.Alignment.bottomCenter,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey700, width: 0.8),
                ),
              ),
              child: signature != null
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child:
                          pw.Image(signature, fit: pw.BoxFit.contain),
                    )
                  : null,
            ),
            pw.SizedBox(height: 6),
            pw.Text(rightLabel,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx, CompanySettings company) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${company.companyName} • Enterprise ERP',
            style: const pw.TextStyle(
                fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(
                fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totRow(String label, String value,
      {bool muted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 9,
                color: muted ? PdfColors.grey700 : PdfColors.black,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 9,
                color: muted ? PdfColors.grey700 : PdfColors.black,
              )),
        ],
      ),
    );
  }

  static Future<pw.ImageProvider?> _loadImage(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      return pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }
}

class _InfoBlock {
  final String label;
  final String value;
  final int span;
  final pw.TextAlign align;

  _InfoBlock(this.label, this.value,
      {this.span = 1, this.align = pw.TextAlign.left});
}