import '../../../core/domain/money.dart';
import 'sale.dart';

/// Storage port for Sales and their immutable line items.
abstract interface class SaleRepository {
  /// Atomically saves the sale, its lines, an optional initial payment,
  /// and an outbox queue operation for cloud synchronization.
  Future<void> savePendingSale(Sale sale, {Money? initialPayment});

  Future<Sale?> findById(String shopId, String saleId);

  Future<List<Sale>> listCustomerSales(String shopId, String customerId);

  Future<List<Sale>> listShopSales(String shopId, {int limit = 50});

  /// Computes the next receipt number sequentially for the shop (e.g. `R-0001`).
  Future<String> nextReceiptNumber(String shopId);

  /// Performs an auditable reversal of a posted sale.
  Future<void> reverseSale(
    String shopId,
    String saleId, {
    required String reason,
    required DateTime reversedAt,
  });
}
