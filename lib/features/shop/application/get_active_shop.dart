import '../domain/shop.dart';
import '../domain/shop_repository.dart';

/// Use case: load the shop currently selected on this device (or null).
final class GetActiveShop {
  const GetActiveShop(this._shops);

  final ShopRepository _shops;

  Future<Shop?> execute() async {
    final id = await _shops.activeShopId();
    return id == null ? null : _shops.findById(id);
  }
}
