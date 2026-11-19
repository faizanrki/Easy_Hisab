import '../domain/sale.dart';
import '../domain/sale_repository.dart';

final class GetSale {
  const GetSale(this._sales);

  final SaleRepository _sales;

  Future<Sale?> byId(String shopId, String saleId) =>
      _sales.findById(shopId, saleId);

  Future<List<Sale>> forCustomer(String shopId, String customerId) =>
      _sales.listCustomerSales(shopId, customerId);

  Future<List<Sale>> forShop(String shopId, {int limit = 50}) =>
      _sales.listShopSales(shopId, limit: limit);
}
