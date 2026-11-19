import '../../../core/contracts/customer_lookup_port.dart';
import '../domain/customer.dart';

abstract final class CustomerMapper {
  static Map<String, Object?> toRow(Customer customer) => {
        'id': customer.id,
        'shop_id': customer.shopId,
        'name': customer.name,
        'name_search': customer.nameSearch,
        'phone': customer.phone,
        'email': customer.email,
        'linked_auth_uid': customer.linkedAuthUid,
        'archived_at': customer.archivedAt?.millisecondsSinceEpoch,
        'created_at': customer.createdAt.millisecondsSinceEpoch,
        'updated_at': customer.updatedAt.millisecondsSinceEpoch,
      };

  static Customer fromRow(Map<String, Object?> row) => Customer(
        id: row['id']! as String,
        shopId: row['shop_id']! as String,
        details: CustomerDetails.fromStorage(
          name: row['name']! as String,
          nameSearch: row['name_search']! as String,
          phone: row['phone'] as String?,
          email: row['email'] as String?,
        ),
        linkedAuthUid: row['linked_auth_uid'] as String?,
        archivedAt: row['archived_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row['archived_at']! as int,
                isUtc: true,
              )
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at']! as int,
          isUtc: true,
        ),
      );

  static CustomerSummary toSummary(Customer customer) => CustomerSummary(
        id: customer.id,
        shopId: customer.shopId,
        name: customer.name,
        phone: customer.phone,
        isArchived: customer.isArchived,
      );
}
