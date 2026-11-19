import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';
import 'shop_mapper.dart';

/// SQLite implementation of [ShopRepository].
final class SqliteShopRepository implements ShopRepository {
  const SqliteShopRepository(this._db, this._ids);

  final DatabaseTransactionPort _db;
  final IdGenerator _ids;

  static const String _activeShopKey = 'active_shop_id';

  @override
  Future<void> createAndActivate(Shop shop) => _guard(() {
        return _db.inTransaction((tx) async {
          await tx.insert('shops', ShopMapper.toRow(shop));
          await tx.insert(
            'app_settings',
            {'key': _activeShopKey, 'value': shop.id},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await _audit(tx, shop, 'shop.created');
        });
      });

  @override
  Future<void> update(Shop shop) => _guard(() {
        return _db.inTransaction((tx) async {
          final row = ShopMapper.toRow(shop)
            ..remove('id')
            ..remove('created_at')
            ..remove('owner_uid');
          final count = await tx
              .update('shops', row, where: 'id = ?', whereArgs: [shop.id]);
          if (count == 0) throw const NotFoundFailure('Shop not found');
          await _audit(tx, shop, 'shop.updated');
        });
      });

  @override
  Future<Shop?> findById(String shopId) => _guard(() async {
        final rows = await _db.executor
            .query('shops', where: 'id = ?', whereArgs: [shopId], limit: 1);
        return rows.isEmpty ? null : ShopMapper.fromRow(rows.first);
      });

  @override
  Future<Shop?> findByOwnerUid(String ownerUid) => _guard(() async {
        final rows = await _db.executor.query(
          'shops',
          where: 'owner_uid = ?',
          whereArgs: [ownerUid],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        return rows.isEmpty ? null : ShopMapper.fromRow(rows.first);
      });

  @override
  Future<String?> activeShopId() => _guard(() async {
        final rows = await _db.executor.query('app_settings',
            where: 'key = ?', whereArgs: [_activeShopKey], limit: 1);
        return rows.isEmpty ? null : rows.first['value'] as String?;
      });

  Future<void> _audit(DatabaseExecutor tx, Shop shop, String action) =>
      tx.insert('audit_log', {
        'id': _ids.newId(),
        'shop_id': shop.id,
        'actor_uid': shop.ownerUid,
        'action': action,
        'record_type': 'shop',
        'record_id': shop.id,
        'details': jsonEncode({
          'name': shop.name,
          'address': shop.address,
          'contact_phone': shop.contactPhone,
        }),
        'created_at': shop.updatedAt.millisecondsSinceEpoch,
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Could not save shop data', e);
    }
  }
}
