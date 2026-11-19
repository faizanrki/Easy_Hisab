import 'dart:convert';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:easy_hisab/features/receipts/data/pdf_receipt_renderer.dart';
import 'package:easy_hisab/features/receipts/domain/receipt_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testReceipt = ReceiptData(
    saleId: 'sale-1',
    receiptNo: 'R-0001',
    shopName: 'Madina Grocery',
    shopAddress: 'Main Bazar, Lahore',
    shopPhone: '+923001234567',
    customerName: 'Tariq Mehmood',
    customerPhone: '+923007654321',
    date: DateTime.utc(2026, 11, 20, 10, 30),
    saleType: 'Credit (Udhar)',
    total: const Money.rupees(2500),
    initialPayment: const Money.rupees(1000),
    remainingUdhar: const Money.rupees(1500),
    note: 'Weekly ration',
    items: [
      ReceiptItemData(
        description: 'Super Basmati Rice',
        unit: 'kg',
        quantity: const Quantity.whole(5),
        unitPrice: const Money.rupees(300),
        lineTotal: const Money.rupees(1500),
      ),
      ReceiptItemData(
        description: 'Cooking Oil',
        unit: 'ltr',
        quantity: const Quantity.whole(2),
        unitPrice: const Money.rupees(500),
        lineTotal: const Money.rupees(1000),
      ),
    ],
  );

  group('ReceiptData WhatsApp Formatting', () {
    test('generates formatted WhatsApp text summary with all transaction details', () {
      final msg = testReceipt.formatWhatsAppText();

      expect(msg, contains('MADINA GROCERY'));
      expect(msg, contains('Main Bazar, Lahore'));
      expect(msg, contains('R-0001'));
      expect(msg, contains('Tariq Mehmood'));
      expect(msg, contains('Super Basmati Rice (5 kg × Rs 300) = *Rs 1,500*'));
      expect(msg, contains('Cooking Oil (2 ltr × Rs 500) = *Rs 1,000*'));
      expect(msg, contains('*Total Bill:* Rs 2,500'));
      expect(msg, contains('Paid at Bill: Rs 1,000'));
      expect(msg, contains('*Total Current Udhar Due:* Rs 1,500'));
      expect(msg, contains('Weekly ration'));
      expect(msg, contains('EasyHisab'));
    });

    test('includes cancelled warning when sale is reversed', () {
      final reversedReceipt = ReceiptData(
        saleId: 'sale-rev',
        receiptNo: 'R-0002',
        shopName: 'Madina Grocery',
        customerName: 'Tariq Mehmood',
        date: DateTime.utc(2026, 11, 20, 10, 30),
        saleType: 'Credit (Udhar)',
        total: const Money.rupees(500),
        isReversed: true,
        items: [
          ReceiptItemData(
            description: 'Sugar',
            unit: 'kg',
            quantity: const Quantity.whole(2),
            unitPrice: const Money.rupees(250),
            lineTotal: const Money.rupees(500),
          ),
        ],
      );

      final msg = reversedReceipt.formatWhatsAppText();
      expect(msg, contains('STATUS: REVERSED / CANCELLED'));
    });
  });

  group('PdfReceiptRenderer', () {
    test('renders valid non-empty vector PDF with PDF header magic bytes', () async {
      const renderer = PdfReceiptRenderer();
      final pdfBytes = await renderer.renderReceiptPdf(testReceipt);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(500));

      // PDF files always begin with the magic header '%PDF-'
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('renders reversed receipt with cancelled banner without throwing', () async {
      final reversedReceipt = ReceiptData(
        saleId: 'sale-rev',
        receiptNo: 'R-0002',
        shopName: 'Madina Grocery',
        customerName: 'Tariq Mehmood',
        date: DateTime.utc(2026, 11, 20, 10, 30),
        saleType: 'Credit (Udhar)',
        total: const Money.rupees(500),
        isReversed: true,
        items: [
          ReceiptItemData(
            description: 'Sugar',
            unit: 'kg',
            quantity: const Quantity.whole(2),
            unitPrice: const Money.rupees(250),
            lineTotal: const Money.rupees(500),
          ),
        ],
      );

      const renderer = PdfReceiptRenderer();
      final pdfBytes = await renderer.renderReceiptPdf(reversedReceipt);

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
