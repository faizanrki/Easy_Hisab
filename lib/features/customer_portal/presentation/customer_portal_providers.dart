import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/sqlite_customer_portal_repository.dart';
import '../domain/customer_portal_repository.dart';
import '../domain/linked_shop.dart';

final customerPortalRepositoryProvider =
    Provider<CustomerPortalRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final idGen = ref.watch(idGeneratorProvider);
  return SqliteCustomerPortalRepository(db, idGen);
});

class CustomerPhoneNumberNotifier extends Notifier<String?> {
  @override
  String? build() {
    final authService = ref.watch(authServiceProvider);
    return authService.currentUser?.phoneNumber;
  }

  void setPhone(String? phone) {
    state = phone;
  }
}

/// Current customer query phone number, if entered.
final customerPhoneNumberProvider =
    NotifierProvider<CustomerPhoneNumberNotifier, String?>(
  CustomerPhoneNumberNotifier.new,
);

/// Provides the list of linked shops for the current customer session/phone.
final linkedShopsProvider =
    FutureProvider.autoDispose<List<LinkedShopSummary>>((ref) async {
  final repo = ref.watch(customerPortalRepositoryProvider);
  final authContext = ref.watch(authContextProvider);
  final phone = ref.watch(customerPhoneNumberProvider);

  // Use authenticated UID or fallback to anonymous customer identifier
  final uid = authContext.currentUid ?? (phone != null ? 'phone_$phone' : 'guest_customer');

  return repo.getLinkedShops(
    customerUid: uid,
    phone: phone,
  );
});

/// Provides the ledger items for a specific shop.
final customerShopLedgerProvider = FutureProvider.family
    .autoDispose<List<CustomerLedgerItem>, ({String shopId, String customerId})>(
        (ref, arg) async {
  final repo = ref.watch(customerPortalRepositoryProvider);
  return repo.getShopLedger(
    shopId: arg.shopId,
    customerId: arg.customerId,
  );
});
