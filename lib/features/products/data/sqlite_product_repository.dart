import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/contracts/product_lookup_port.dart';
import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'product_mapper.dart';

final class SqliteProductRepository
    implements ProductRepository, ProductLookupPort {
  const SqliteProductRepository(this._db, this._ids);

  final DatabaseTransactionPort _db;
  final IdGenerator _ids;

  @override
  Future<void> save(Product product) => _guard(() async {
        await _db.inTransaction((tx) async {
          await tx.insert('products', ProductMapper.toRow(product));
          await _audit(tx, product.shopId, product.id, 'product.created', {
            'name': product.name,
            'unit': product.unit,
            'unit_price_paisa': product.unitPrice.paisa,
          });
        });
      });

  @override
  Future<void> update(Product product) => _guard(() async {
        await _db.inTransaction((tx) async {
          final row = ProductMapper.toRow(product)
            ..remove('id')
            ..remove('shop_id')
            ..remove('created_at');

          final count = await tx.update(
            'products',
            row,
            where: 'id = ? AND shop_id = ?',
            whereArgs: [product.id, product.shopId],
          );

          if (count == 0) {
            throw const NotFoundFailure('Product not found');
          }

          await _audit(tx, product.shopId, product.id, 'product.updated', {
            'name': product.name,
            'unit': product.unit,
            'unit_price_paisa': product.unitPrice.paisa,
          });
        });
      });

  @override
  Future<Product?> findById(String shopId, String productId) =>
      _guard(() async {
        final rows = await _db.executor.query(
          'products',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [productId, shopId],
          limit: 1,
        );
        return rows.isEmpty ? null : ProductMapper.fromRow(rows.first);
      });

  @override
  Future<List<Product>> listForShop(
    String shopId, {
    String? searchQuery,
    bool includeArchived = false,
  }) =>
      _guard(() async {
        final conditions = <String>['shop_id = ?'];
        final args = <Object?>[shopId];

        if (!includeArchived) {
          conditions.add('archived_at IS NULL');
        }

        final query = searchQuery?.trim().toLowerCase();
        if (query != null && query.isNotEmpty) {
          conditions.add('name_search LIKE ?');
          args.add('%$query%');
        }

        final rows = await _db.executor.query(
          'products',
          where: conditions.join(' AND '),
          whereArgs: args,
          orderBy: 'name_search ASC',
        );

        return rows.map(ProductMapper.fromRow).toList();
      });

  @override
  Future<void> setArchivedStatus(
    String shopId,
    String productId, {
    required bool archived,
    required DateTime timestamp,
  }) =>
      _guard(() async {
        await _db.inTransaction((tx) async {
          final count = await tx.update(
            'products',
            {
              'archived_at':
                  archived ? timestamp.millisecondsSinceEpoch : null,
              'updated_at': timestamp.millisecondsSinceEpoch,
            },
            where: 'id = ? AND shop_id = ?',
            whereArgs: [productId, shopId],
          );

          if (count == 0) {
            throw const NotFoundFailure('Product not found');
          }

          await _audit(
            tx,
            shopId,
            productId,
            archived ? 'product.archived' : 'product.unarchived',
            {},
          );
        });
      });

  // Implements ProductLookupPort for Sales/Billing module
  @override
  Future<ProductSnapshot?> findForShop({
    required String shopId,
    required String productId,
  }) async {
    final product = await findById(shopId, productId);
    return product == null ? null : ProductMapper.toSnapshot(product);
  }

  Future<void> _audit(
    DatabaseExecutor tx,
    String shopId,
    String productId,
    String action,
    Map<String, dynamic> details,
  ) =>
      tx.insert('audit_log', {
        'id': _ids.newId(),
        'shop_id': shopId,
        'actor_uid': null,
        'action': action,
        'record_type': 'product',
        'record_id': productId,
        'details': jsonEncode(details),
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Could not query product data', e);
    }
  }
}
