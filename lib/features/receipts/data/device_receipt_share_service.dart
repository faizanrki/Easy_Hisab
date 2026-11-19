import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/receipt_ports.dart';
import '../domain/receipt_data.dart';

final class DeviceReceiptShareService implements ReceiptShareServicePort {
  const DeviceReceiptShareService();

  @override
  Future<void> shareReceiptPdf(ReceiptData receipt, Uint8List pdfBytes) async {
    final cleanReceiptNo = receipt.receiptNo.replaceAll(RegExp(r'[^\w-]'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'receipt_$cleanReceiptNo.pdf',
    );
  }

  @override
  Future<void> printReceiptPdf(ReceiptData receipt, Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Bill_${receipt.receiptNo}',
    );
  }

  @override
  Future<bool> shareToWhatsApp({
    required String? phone,
    required String message,
  }) async {
    String? cleanPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      // Keep only digits
      cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      // If starts with 03, convert to 923...
      if (cleanPhone.startsWith('03')) {
        cleanPhone = '92${cleanPhone.substring(1)}';
      }
    }

    final encodedMessage = Uri.encodeComponent(message);
    final urlString = cleanPhone != null && cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
        : 'https://wa.me/?text=$encodedMessage';

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
