import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  late SqliteShopRepository repository;
  const idGen = UuidIdGenerator();

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repository = SqliteShopRepository(db, idGen);
  });

  tearDown(() => db.close());

  test('creates shop and sets it as active shop', () async {
    final now = DateTime.utc(2026, 11, 19, 12, 0);
    final shop = Shop(
      id: 'shop-uuid-1',
      details: ShopDetails.create(
        name: 'Madina Store',
        address: 'Main Bazaar',
        contactPhone: '03001234567',
      ),
      createdAt: now,
      updatedAt: now,
    );

    await repository.createAndActivate(shop);

    final activeId = await repository.activeShopId();
    expect(activeId, 'shop-uuid-1');

    final fetched = await repository.findById('shop-uuid-1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Madina Store');
    expect(fetched.address, 'Main Bazaar');
    expect(fetched.contactPhone, '+923001234567');

    // Verify audit log has the event
    final auditLogs = await db.executor.query('audit_log');
    expect(auditLogs, hasLength(1));
    expect(auditLogs.first['action'], 'shop.created');
    expect(auditLogs.first['record_id'], 'shop-uuid-1');
  });

  test('updates existing shop details and adds audit entry', () async {
    final now = DateTime.utc(2026, 11, 19, 12, 0);
    final shop = Shop(
      id: 'shop-uuid-2',
      details: ShopDetails.create(name: 'Initial Name'),
      createdAt: now,
      updatedAt: now,
    );

    await repository.createAndActivate(shop);

    final updated = shop.copyWith(
      details: ShopDetails.create(
        name: 'Updated Name Store',
        address: 'Sector F-7, Islamabad',
        contactPhone: '03009999999',
      ),
      updatedAt: now.add(const Duration(minutes: 10)),
    );

    await repository.update(updated);

    final fetched = await repository.findById('shop-uuid-2');
    expect(fetched!.name, 'Updated Name Store');
    expect(fetched.address, 'Sector F-7, Islamabad');
    expect(fetched.contactPhone, '+923009999999');

    final auditLogs = await db.executor.query(
      'audit_log',
      where: 'action = ?',
      whereArgs: ['shop.updated'],
    );
    expect(auditLogs, hasLength(1));
  });
}
