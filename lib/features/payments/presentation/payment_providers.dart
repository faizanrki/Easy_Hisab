import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../../core/domain/money.dart';
import '../../customers/customers_public.dart';
import '../../shop/shop_public.dart';
import '../application/get_customer_ledger.dart';
import '../application/record_payment.dart';
import '../application/reverse_payment.dart';
import '../data/sqlite_payment_repository.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqlitePaymentRepository(db, ids);
});

final recordPaymentUseCaseProvider = Provider<RecordPayment>((ref) {
  final payments = ref.watch(paymentRepositoryProvider);
  final customers = ref.watch(customerLookupPortProvider);
  final ids = ref.watch(idGeneratorProvider);
  final clock = ref.watch(clockProvider);
  return RecordPayment(payments, customers, ids, clock);
});

final reversePaymentUseCaseProvider = Provider<ReversePayment>((ref) {
  final payments = ref.watch(paymentRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return ReversePayment(payments, clock);
});

final getCustomerLedgerUseCaseProvider = Provider<GetCustomerLedger>((ref) {
  final payments = ref.watch(paymentRepositoryProvider);
  return GetCustomerLedger(payments);
});

final getCustomerBalanceUseCaseProvider = Provider<GetCustomerBalance>((ref) {
  final payments = ref.watch(paymentRepositoryProvider);
  return GetCustomerBalance(payments);
});

/// Computes current net outstanding balance for a customer.
final customerBalanceProvider =
    FutureProvider.autoDispose.family<Money, String>((ref, customerId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return Money.zero;

  final getBalance = ref.watch(getCustomerBalanceUseCaseProvider);
  return getBalance.execute(
    shopId: shopContext.shopId,
    customerId: customerId,
  );
});

/// Returns customer's khata transaction ledger.
final customerLedgerProvider = FutureProvider.autoDispose
    .family<List<LedgerEntry>, String>((ref, customerId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final getLedger = ref.watch(getCustomerLedgerUseCaseProvider);
  return getLedger.execute(
    shopId: shopContext.shopId,
    customerId: customerId,
  );
});

/// List of recent payments across the active shop.
final recentPaymentsProvider =
    FutureProvider.autoDispose<List<Payment>>((ref) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final repo = ref.watch(paymentRepositoryProvider);
  return repo.listShopPayments(shopContext.shopId);
});

/// Single payment detail by ID.
final paymentDetailProvider =
    FutureProvider.autoDispose.family<Payment?, String>((ref, paymentId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return null;

  final repo = ref.watch(paymentRepositoryProvider);
  return repo.findById(shopContext.shopId, paymentId);
});
