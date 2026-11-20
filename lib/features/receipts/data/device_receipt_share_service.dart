import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
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

    // 1. Try native WhatsApp URI scheme first
    final nativeUri = Uri.parse(
      cleanPhone != null && cleanPhone.isNotEmpty
          ? 'whatsapp://send?phone=$cleanPhone&text=$encodedMessage'
          : 'whatsapp://send?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (_) {
      // Ignore and fallback to web wa.me
    }

    // 2. Try web wa.me URL
    final webUri = Uri.parse(
      cleanPhone != null && cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
          : 'https://wa.me/?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(webUri)) {
        final launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (_) {
      // Ignore and fallback to share_plus
    }

    // 3. Fallback to general system share dialog
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'EasyHisab Bill Receipt',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
