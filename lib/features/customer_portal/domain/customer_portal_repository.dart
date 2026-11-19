import 'linked_shop.dart';

abstract interface class CustomerPortalRepository {
  /// Fetches all shops linked to this user's UID or matching phone number.
  Future<List<LinkedShopSummary>> getLinkedShops({
    required String customerUid,
    String? phone,
  });

  /// Fetches chronological ledger entries (sales and payments) for a customer at a shop.
  Future<List<CustomerLedgerItem>> getShopLedger({
    required String shopId,
    required String customerId,
  });

  /// Links all shop accounts matching a customer's phone number to their UID.
  Future<int> linkByPhoneNumber({
    required String customerUid,
    required String phone,
  });

  /// Manually link a customer to a shop using shopId and customerId.
  Future<void> linkAccount({
    required String customerUid,
    required String shopId,
    required String customerId,
  });
}
