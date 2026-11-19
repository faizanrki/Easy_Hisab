import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../customers/customers_public.dart';
import '../../shop/shop_public.dart';
import '../application/create_sale.dart';
import '../application/get_sale.dart';
import '../application/reverse_sale.dart';
import '../data/sqlite_sale_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteSaleRepository(db, ids);
});

final createSaleUseCaseProvider = Provider<CreateSale>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  final customers = ref.watch(customerLookupPortProvider);
  final ids = ref.watch(idGeneratorProvider);
  final clock = ref.watch(clockProvider);
  return CreateSale(repo, customers, ids, clock);
});

final reverseSaleUseCaseProvider = Provider<ReverseSale>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return ReverseSale(repo, clock);
});

final getSaleUseCaseProvider = Provider<GetSale>((ref) {
  final repo = ref.watch(saleRepositoryProvider);
  return GetSale(repo);
});

final saleDetailProvider =
    FutureProvider.autoDispose.family<Sale?, String>((ref, saleId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return null;

  final getSale = ref.watch(getSaleUseCaseProvider);
  return getSale.byId(shopContext.shopId, saleId);
});

final recentSalesProvider =
    FutureProvider.autoDispose<List<Sale>>((ref) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final getSale = ref.watch(getSaleUseCaseProvider);
  return getSale.forShop(shopContext.shopId, limit: 30);
});

final customerSalesProvider =
    FutureProvider.autoDispose.family<List<Sale>, String>((ref, customerId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final getSale = ref.watch(getSaleUseCaseProvider);
  return getSale.forCustomer(shopContext.shopId, customerId);
});
