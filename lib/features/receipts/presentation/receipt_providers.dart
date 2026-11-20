import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/app_failure.dart';
import '../../customer_portal/application/customer_token_service.dart';
import '../../customer_portal/presentation/customer_portal_providers.dart';
import '../../customers/customers_public.dart';
import '../../payments/payments_public.dart';
import '../../sales/sales_public.dart';
import '../../shop/shop_public.dart';
import '../application/receipt_ports.dart';
import '../data/device_receipt_share_service.dart';
import '../data/pdf_receipt_renderer.dart';
import '../domain/receipt_data.dart';

final receiptRendererProvider = Provider<ReceiptRendererPort>((ref) {
  return const PdfReceiptRenderer();
});

final receiptShareServiceProvider = Provider<ReceiptShareServicePort>((ref) {
  return const DeviceReceiptShareService();
});

/// Assembles the self-contained ReceiptData DTO for a given sale.
final receiptDataProvider =
    FutureProvider.autoDispose.family<ReceiptData, String>((ref, saleId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) {
    throw const NotFoundFailure('No active shop found');
  }

  final saleRepo = ref.watch(saleRepositoryProvider);
  final sale = await saleRepo.findById(shopContext.shopId, saleId);
  if (sale == null) {
    throw const NotFoundFailure('Sale record not found');
  }

  final shop = ref.watch(activeShopProvider).value;

  final customerLookup = ref.watch(customerLookupPortProvider);
  final customer = await customerLookup.findForShop(
    shopId: shopContext.shopId,
    customerId: sale.customerId,
  );

  final balance = await ref.watch(customerBalanceProvider(sale.customerId).future);

  final items = sale.items.map((line) {
    return ReceiptItemData(
      productId: line.productId,
      description: line.description,
      unit: line.unit,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      lineTotal: line.lineTotal,
    );
  }).toList();

  final tokenService = ref.watch(customerTokenServiceProvider);
  final token = await tokenService.getOrGenerateToken(
    shopId: shopContext.shopId,
    customerId: sale.customerId,
  );

  return ReceiptData(
    saleId: sale.id,
    receiptNo: sale.receiptNo,
    shopName: shop?.name ?? shopContext.shopName,
    shopAddress: shop?.address,
    shopPhone: shop?.contactPhone,
    shopCode: shop?.shopCode ?? CustomerTokenService.formatShopCode(shopContext.shopId),
    accessToken: token,
    customerName: customer?.name ?? 'Customer (${sale.customerId})',
    customerPhone: customer?.phone,
    date: sale.createdAt,
    saleType: sale.isCredit ? 'Credit (Udhar)' : 'Cash Paid',
    total: sale.total,
    remainingUdhar: sale.isCredit ? balance : null,
    note: sale.note,
    isReversed: sale.isReversed,
    items: items,
  );
});

/// Renders the PDF bytes for a given sale.
final receiptPdfBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, saleId) async {
  final receipt = await ref.watch(receiptDataProvider(saleId).future);
  final renderer = ref.read(receiptRendererProvider);
  return renderer.renderReceiptPdf(receipt);
});
