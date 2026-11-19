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

    // Clean 80mm receipt roll (226 points wide) with auto height
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Shop branding)
                pw.Center(
                  child: pw.Text(
                    receipt.shopName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (receipt.shopAddress != null &&
                    receipt.shopAddress!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      receipt.shopAddress!,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (receipt.shopPhone != null &&
                    receipt.shopPhone!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      'Tel: ${receipt.shopPhone!}',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),

                // 2. Receipt metadata
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bill #: ${receipt.receiptNo}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(receipt.saleType.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text('Date: $dateStr',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Customer: ${receipt.customerName}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (receipt.customerPhone != null)
                  pw.Text('Phone: ${receipt.customerPhone!}',
                      style: const pw.TextStyle(fontSize: 8)),

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

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),

                // 3. Itemized Products Table
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3.5),
                    1: pw.FlexColumnWidth(1.5),
                    2: pw.FlexColumnWidth(2.0),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(width: 0.5),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Text('Item',
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
                          child: pw.Text('Total',
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
                                    style: const pw.TextStyle(fontSize: 8)),
                                pw.Text(
                                  '@ ${item.unitPrice.format()}/${item.unit}',
                                  style: const pw.TextStyle(
                                    fontSize: 7,
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
                              style: const pw.TextStyle(fontSize: 8),
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

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),

                // 4. Totals Breakdown
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Bill:',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(receipt.total.format(),
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
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
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Current Udhar Due:',
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(receipt.remainingUdhar!.format(),
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],

                if (receipt.note != null && receipt.note!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Note: ${receipt.note!}',
                      style: const pw.TextStyle(fontSize: 7)),
                ],

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.5),

                // 5. Footer
                pw.Center(
                  child: pw.Text(
                    'Shukriya! Thank you for your visit.',
                    style: const pw.TextStyle(fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Powered by EasyHisab - Digital Khata',
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700),
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
