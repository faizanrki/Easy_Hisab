import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../application/receipt_ports.dart';
import '../domain/receipt_data.dart';

final class PdfReceiptRenderer implements ReceiptRendererPort {
  const PdfReceiptRenderer();

  @override
  Future<Uint8List> renderReceiptPdf(ReceiptData receipt) async {
    final doc = pw.Document(
      title: 'Receipt ${receipt.receiptNo}',
      author: receipt.shopName,
    );

    final dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(receipt.date.toLocal());

    // Standard high-resolution 80mm POS receipt format (226.77 pt width)
    // with fixed margin and crisp vector elements
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      220 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. App Brand Badge (EasyHisab Logo)
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#1B5E20'), // EasyHisab forest green
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'EASYHISAB • DIGITAL KHATA',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),

                // 2. Shopkeeper Name & Details
                pw.Center(
                  child: pw.Text(
                    receipt.shopName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (receipt.shopAddress != null &&
                    receipt.shopAddress!.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      receipt.shopAddress!,
                      style: const pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.grey800),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (receipt.shopPhone != null &&
                    receipt.shopPhone!.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      'Phone: ${receipt.shopPhone!}',
                      style: const pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.grey800),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],

                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600),

                // 3. Receipt Metadata Bar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bill #: ${receipt.receiptNo}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                      child: pw.Text(
                        receipt.saleType.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text('Date: $dateStr',
                    style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('Customer: ${receipt.customerName}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (receipt.customerPhone != null)
                  pw.Text('Customer Phone: ${receipt.customerPhone!}',
                      style: const pw.TextStyle(fontSize: 7.5)),

                if (receipt.isReversed) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    color: PdfColors.red50,
                    child: pw.Center(
                      child: pw.Text(
                        '** CANCELLED / REVERSED **',
                        style: pw.TextStyle(
                          color: PdfColors.red900,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600),

                // 4. Itemized Products Table
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4.0),
                    1: pw.FlexColumnWidth(1.6),
                    2: pw.FlexColumnWidth(2.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey600),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text('Item Description',
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text('Qty',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text('Total (Rs)',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...receipt.items.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(item.description,
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.Text(
                                  '@ ${item.unitPrice.format()}/${item.unit}',
                                  style: const pw.TextStyle(
                                    fontSize: 6.8,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Text(
                              '${item.quantity.format()} ${item.unit}',
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 7.5),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Text(
                              item.lineTotal.format(),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600),

                // 5. Totals Breakdown
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal / Total Bill:',
                        style: pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text(receipt.total.format(),
                        style: pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),

                if (receipt.initialPayment != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cash Paid at Bill:',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(receipt.initialPayment!.format(),
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],

                if (receipt.remainingUdhar != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Current Udhar Due:',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(receipt.remainingUdhar!.format(),
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red900)),
                      ],
                    ),
                  ),
                ],

                if (receipt.note != null && receipt.note!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Note: ${receipt.note!}',
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.grey800)),
                ],

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.5, color: PdfColors.grey500),

                // 6. Clean Footer
                pw.Center(
                  child: pw.Text(
                    'Shukriya! Thank you for your business.',
                    style: pw.TextStyle(
                        fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Computer generated digital invoice • EasyHisab',
                    style: const pw.TextStyle(
                        fontSize: 6.5, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }
}
