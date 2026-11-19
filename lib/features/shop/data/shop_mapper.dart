import '../domain/shop.dart';

/// Converts between [Shop] and its `shops` table row. Private to the feature.
abstract final class ShopMapper {
  static Map<String, Object?> toRow(Shop shop) => {
        'id': shop.id,
        'owner_uid': shop.ownerUid,
        'name': shop.name,
        'address': shop.address,
        'contact_phone': shop.contactPhone,
        'business_verification': shop.businessVerification.name,
        'created_at': shop.createdAt.millisecondsSinceEpoch,
        'updated_at': shop.updatedAt.millisecondsSinceEpoch,
      };

  static Shop fromRow(Map<String, Object?> row) => Shop(
        id: row['id']! as String,
        ownerUid: row['owner_uid'] as String?,
        details: ShopDetails.fromStorage(
          name: row['name']! as String,
          address: row['address'] as String?,
          contactPhone: row['contact_phone'] as String?,
        ),
        businessVerification: BusinessVerification.values
            .byName(row['business_verification']! as String),
        createdAt: _utc(row['created_at']! as int),
        updatedAt: _utc(row['updated_at']! as int),
      );

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
