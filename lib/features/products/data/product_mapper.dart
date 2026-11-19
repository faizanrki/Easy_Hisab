import '../../../core/contracts/product_lookup_port.dart';
import '../../../core/domain/money.dart';
import '../domain/product.dart';

abstract final class ProductMapper {
  static Map<String, Object?> toRow(Product product) => {
        'id': product.id,
        'shop_id': product.shopId,
        'name': product.name,
        'name_search': product.nameSearch,
        'unit': product.unit,
        'unit_price_paisa': product.unitPrice.paisa,
        'archived_at': product.archivedAt?.millisecondsSinceEpoch,
        'created_at': product.createdAt.millisecondsSinceEpoch,
        'updated_at': product.updatedAt.millisecondsSinceEpoch,
      };

  static Product fromRow(Map<String, Object?> row) => Product(
        id: row['id']! as String,
        shopId: row['shop_id']! as String,
        details: ProductDetails.fromStorage(
          name: row['name']! as String,
          nameSearch: row['name_search']! as String,
          unit: row['unit']! as String,
          unitPrice: Money.paisa(row['unit_price_paisa']! as int),
        ),
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

  static ProductSnapshot toSnapshot(Product product) => ProductSnapshot(
        id: product.id,
        shopId: product.shopId,
        name: product.name,
        unit: product.unit,
        unitPrice: product.unitPrice,
        isArchived: product.isArchived,
      );
}
