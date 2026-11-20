import 'package:intl/intl.dart';

import '../../../core/domain/money.dart';
import '../../../core/domain/quantity.dart';

final class ReceiptItemData {
  const ReceiptItemData({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
  });

  final String description;
  final String unit;
  final Quantity quantity;
  final Money unitPrice;
  final Money lineTotal;
  final String? productId;
}

/// A self-contained, read-only DTO for rendering printable PDFs and sharing.
/// Contains snapshots captured at the exact moment of billing.
final class ReceiptData {
  const ReceiptData({
    required this.saleId,
    required this.receiptNo,
    required this.shopName,
    required this.customerName,
    required this.date,
    required this.saleType,
    required this.total,
    required this.items,
    this.shopAddress,
    this.shopPhone,
    this.shopCode,
    this.accessToken,
    this.customerPhone,
    this.initialPayment,
    this.remainingUdhar,
    this.note,
    this.isReversed = false,
  });

  final String saleId;
  final String receiptNo;
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopCode;
  final String? accessToken;
  final String customerName;
  final String? customerPhone;
  final DateTime date;
  final String saleType;
  final Money total;
  final Money? initialPayment;
  final Money? remainingUdhar;
  final String? note;
  final bool isReversed;
  final List<ReceiptItemData> items;

  /// Builds a formatted text message for WhatsApp sharing.
  String formatWhatsAppText() {
    final buffer = StringBuffer();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());

    buffer.writeln('🧾 *${shopName.toUpperCase()}*');
    if (shopAddress != null && shopAddress!.isNotEmpty) {
      buffer.writeln('📍 $shopAddress');
    }
    if (shopPhone != null && shopPhone!.isNotEmpty) {
      buffer.writeln('📞 $shopPhone');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('Bill #: *$receiptNo*');
    buffer.writeln('Date: $dateStr');
    buffer.writeln('Customer: *$customerName*');
    if (isReversed) {
      buffer.writeln('⚠️ *STATUS: REVERSED / CANCELLED*');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*Purchased Items:*');

    for (final item in items) {
      buffer.writeln(
        '• ${item.description} (${item.quantity.format()} ${item.unit} × ${item.unitPrice.format()}) = *${item.lineTotal.format()}*',
      );
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('*Total Bill:* ${total.format()}');
    buffer.writeln('Type: $saleType');

    if (initialPayment != null && initialPayment! > Money.zero) {
      buffer.writeln('Paid at Bill: ${initialPayment!.format()}');
    }

    if (remainingUdhar != null) {
      buffer.writeln('*Total Current Udhar Due:* ${remainingUdhar!.format()}');
    }

    if (note != null && note!.isNotEmpty) {
      buffer.writeln('Note: $note');
    }

    if (shopCode != null && accessToken != null) {
      buffer.writeln('--------------------------------');
      buffer.writeln('🔑 *ONLINE UDHAR TRACKING:*');
      buffer.writeln('Shop ID: *$shopCode*');
      buffer.writeln('Bill Token: *$accessToken*');
      buffer.writeln('Open EasyHisab app > Customer > Enter Shop ID & Token to check your complete ledger anytime (No phone number needed).');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Thank you for shopping at $shopName!');
    buffer.writeln('_Generated via EasyHisab_');

    return buffer.toString();
  }
}
