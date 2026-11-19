import '../../../core/contracts/auth_context_port.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';

/// Use case: create the first (or another) shop on this device.
final class CreateShop {
  const CreateShop(this._shops, this._ids, this._clock, this._auth);

  final ShopRepository _shops;
  final IdGenerator _ids;
  final Clock _clock;
  final AuthContextPort _auth;

  Future<Shop> execute(ShopDetails details) async {
    final now = _clock.nowUtc();
    final shop = Shop(
      id: _ids.newId(),
      details: details,
      // Null until sign-in exists; bound to the real UID in module 08.
      ownerUid: _auth.currentUid,
      createdAt: now,
      updatedAt: now,
    );
    await _shops.createAndActivate(shop);
    return shop;
  }
}
