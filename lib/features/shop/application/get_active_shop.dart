import '../../../core/contracts/auth_context_port.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';

/// Use case: load the shop currently selected on this device for the active user session.
final class GetActiveShop {
  const GetActiveShop(this._shops, this._auth);

  final ShopRepository _shops;
  final AuthContextPort _auth;

  Future<Shop?> execute() async {
    final uid = _auth.currentUid;
    if (uid != null) {
      // Find the shop owned by this specific authenticated user
      final userShop = await _shops.findByOwnerUid(uid);
      if (userShop != null) {
        return userShop;
      }
      // If the user is logged in but has not created a shop yet, return null
      return null;
    }

    // Guest / local only mode: fallback to local device active shop
    final id = await _shops.activeShopId();
    return id == null ? null : _shops.findById(id);
  }
}
