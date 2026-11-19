import '../../../core/contracts/auth_context_port.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';

/// Use case: edit the shop's name, address or phone.
final class UpdateShop {
  const UpdateShop(this._shops, this._clock, this._auth);

  final ShopRepository _shops;
  final Clock _clock;
  final AuthContextPort _auth;

  Future<Shop> execute(String shopId, ShopDetails details) async {
    final existing = await _shops.findById(shopId);
    if (existing == null) throw const NotFoundFailure('Shop not found');

    // Local check only; the trusted backend re-checks membership (module 08).
    final owner = existing.ownerUid;
    if (owner != null && owner != _auth.currentUid) {
      throw const PermissionFailure('Only the shop owner can edit this shop');
    }

    final updated =
        existing.copyWith(details: details, updatedAt: _clock.nowUtc());
    await _shops.update(updated);
    return updated;
  }
}
