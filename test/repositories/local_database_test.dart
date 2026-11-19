import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/database/migrations/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => db.close());

  const now = 1763560000000;

  Future<void> seedShopAndCustomer(String shopId, String customerId) async {
    await db.executor.insert('shops', {
      'id': shopId,
      'name': 'Shop $shopId',
      'created_at': now,
      'updated_at': now,
    });
    await db.executor.insert('customers', {
      'id': customerId,
      'shop_id': shopId,
      'name': 'Ali',
      'name_search': 'ali',
      'created_at': now,
      'updated_at': now,
    });
  }

  Map<String, Object?> sale(String id, String shopId, String customerId) => {
        'id': id,
        'shop_id': shopId,
        'customer_id': customerId,
        'receipt_no': 'R-$id',
        'sale_type': 'credit',
        'total_paisa': 250000,
        'created_at': now,
      };

  test('creates the latest schema with all spec tables', () async {
    expect(await db.schemaVersion(), latestSchemaVersion);
    final rows = await db.executor.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'");
    final tables = rows.map((r) => r['name']).toSet();
    expect(tables, {
      'users', 'shops', 'shop_members', 'customers', 'products', 'sales',
      'sale_items', 'payments', 'payment_allocations', 'customer_links',
      'reminders', 'sync_queue', 'backup_history', 'audit_log',
      'app_settings',
    });
  });

  test('foreign keys are enforced', () async {
    final fk = await db.executor.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    expect(
      () => db.executor.insert('customers', {
        'id': 'c1',
        'shop_id': 'missing-shop',
        'name': 'Ali',
        'name_search': 'ali',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a sale cannot reference another shop\'s customer', () async {
    await seedShopAndCustomer('shopA', 'custA');
    await seedShopAndCustomer('shopB', 'custB');
    await db.executor.insert('sales', sale('s1', 'shopA', 'custA'));
    expect(
      () => db.executor.insert('sales', sale('s2', 'shopA', 'custB')),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('posted sales cannot be deleted or have amounts changed', () async {
    await seedShopAndCustomer('shopA', 'custA');
    await db.executor.insert('sales', sale('s1', 'shopA', 'custA'));
    expect(() => db.executor.delete('sales'),
        throwsA(isA<DatabaseException>()));
    expect(
      () => db.executor.update('sales', {'total_paisa': 1}),
      throwsA(isA<DatabaseException>()),
    );
    // Sync status is allowed to change.
    await db.executor.update('sales', {'sync_status': 'accepted'});
  });

  test('money columns reject invalid values', () async {
    await seedShopAndCustomer('shopA', 'custA');
    expect(
      () => db.executor.insert('payments', {
        'id': 'p1',
        'shop_id': 'shopA',
        'customer_id': 'custA',
        'amount_paisa': 0,
        'created_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('transactions roll back completely on failure', () async {
    await seedShopAndCustomer('shopA', 'custA');
    await expectLater(
      db.inTransaction((tx) async {
        await tx.insert('sales', sale('s1', 'shopA', 'custA'));
        // Invalid item (quantity 0) -> whole transaction must roll back.
        await tx.insert('sale_items', {
          'id': 'i1',
          'sale_id': 's1',
          'description': 'Sugar',
          'unit': 'kg',
          'quantity_milli': 0,
          'unit_price_paisa': 15000,
          'line_total_paisa': 0,
          'position': 0,
        });
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.executor.query('sales'), isEmpty);
  });
}
