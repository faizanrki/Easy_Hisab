import 'dart:typed_data';

import '../domain/receipt_data.dart';

abstract interface class ReceiptRendererPort {
  /// Renders a crisp vector PDF document for the given receipt data.
  Future<Uint8List> renderReceiptPdf(ReceiptData receipt);
}

abstract interface class ReceiptShareServicePort {
  /// Triggers the Android platform share sheet to send the PDF file.
  Future<void> shareReceiptPdf(ReceiptData receipt, Uint8List pdfBytes);

  /// Launches the system print dialog or network thermal printer.
  Future<void> printReceiptPdf(ReceiptData receipt, Uint8List pdfBytes);

  /// Launches WhatsApp with the formatted text message directed to the phone number.
  Future<bool> shareToWhatsApp({
    required String? phone,
    required String message,
  });
}
