import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/contracts/customer_lookup_port.dart';
import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_mapper.dart';

final class SqliteCustomerRepository
    implements CustomerRepository, CustomerLookupPort {
  const SqliteCustomerRepository(this._db, this._ids);

  final DatabaseTransactionPort _db;
  final IdGenerator _ids;

  @override
  Future<void> save(Customer customer) => _guard(() async {
        await _db.inTransaction((tx) async {
          await tx.insert('customers', CustomerMapper.toRow(customer));
          await _audit(tx, customer.shopId, customer.id, 'customer.created', {
            'name': customer.name,
            'phone': customer.phone,
          });
        });
      });

  @override
  Future<void> update(Customer customer) => _guard(() async {
        await _db.inTransaction((tx) async {
          final row = CustomerMapper.toRow(customer)
            ..remove('id')
            ..remove('shop_id')
            ..remove('created_at');

          final count = await tx.update(
            'customers',
            row,
            where: 'id = ? AND shop_id = ?',
            whereArgs: [customer.id, customer.shopId],
          );

          if (count == 0) {
            throw const NotFoundFailure('Customer not found');
          }

          await _audit(tx, customer.shopId, customer.id, 'customer.updated', {
            'name': customer.name,
            'phone': customer.phone,
          });
        });
      });

  @override
  Future<Customer?> findById(String shopId, String customerId) =>
      _guard(() async {
        final rows = await _db.executor.query(
          'customers',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [customerId, shopId],
          limit: 1,
        );
        return rows.isEmpty ? null : CustomerMapper.fromRow(rows.first);
      });

  @override
  Future<List<Customer>> listForShop(
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
          conditions.add('(name_search LIKE ? OR phone LIKE ?)');
          args.add('%$query%');
          args.add('%$query%');
        }

        final rows = await _db.executor.query(
          'customers',
          where: conditions.join(' AND '),
          whereArgs: args,
          orderBy: 'name_search ASC',
        );

        return rows.map(CustomerMapper.fromRow).toList();
      });

  @override
  Future<void> setArchivedStatus(
    String shopId,
    String customerId, {
    required bool archived,
    required DateTime timestamp,
  }) =>
      _guard(() async {
        await _db.inTransaction((tx) async {
          final count = await tx.update(
            'customers',
            {
              'archived_at':
                  archived ? timestamp.millisecondsSinceEpoch : null,
              'updated_at': timestamp.millisecondsSinceEpoch,
            },
            where: 'id = ? AND shop_id = ?',
            whereArgs: [customerId, shopId],
          );

          if (count == 0) {
            throw const NotFoundFailure('Customer not found');
          }

          await _audit(
            tx,
            shopId,
            customerId,
            archived ? 'customer.archived' : 'customer.unarchived',
            {},
          );
        });
      });

  // Implements CustomerLookupPort for Sales/Payments modules
  @override
  Future<CustomerSummary?> findForShop({
    required String shopId,
    required String customerId,
  }) async {
    final customer = await findById(shopId, customerId);
    return customer == null ? null : CustomerMapper.toSummary(customer);
  }

  Future<void> _audit(
    DatabaseExecutor tx,
    String shopId,
    String customerId,
    String action,
    Map<String, dynamic> details,
  ) =>
      tx.insert('audit_log', {
        'id': _ids.newId(),
        'shop_id': shopId,
        'actor_uid': null,
        'action': action,
        'record_type': 'customer',
        'record_id': customerId,
        'details': jsonEncode(details),
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Could not query customer data', e);
    }
  }
}
