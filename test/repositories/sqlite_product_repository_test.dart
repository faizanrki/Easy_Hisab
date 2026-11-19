import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/products/data/sqlite_product_repository.dart';
import 'package:easy_hisab/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  late SqliteProductRepository repository;
  const idGen = UuidIdGenerator();
  const shopId = 'test-shop-1';
  const otherShopId = 'test-shop-2';

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repository = SqliteProductRepository(db, idGen);

    const nowMs = 1763560000000;
    await db.executor.insert('shops', {
      'id': shopId,
      'name': 'Primary Shop',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    await db.executor.insert('shops', {
      'id': otherShopId,
      'name': 'Other Shop',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
  });

  tearDown(() => db.close());

  Product makeProduct(String id, String name, int rupees, {String unit = 'kg', String targetShop = shopId}) {
    final now = DateTime.utc(2026, 11, 19, 10, 0);
    return Product(
      id: id,
      shopId: targetShop,
      details: ProductDetails.create(
        name: name,
        unit: unit,
        unitPrice: Money.rupees(rupees),
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  test('saves product and retrieves by ID', () async {
    final p = makeProduct('p1', 'Sugar', 150);
    await repository.save(p);

    final fetched = await repository.findById(shopId, 'p1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Sugar');
    expect(fetched.unit, 'kg');
    expect(fetched.unitPrice.paisa, 15000);
    expect(fetched.isArchived, isFalse);

    // Audit trail record
    final logs = await db.executor.query('audit_log', where: 'record_id = ?', whereArgs: ['p1']);
    expect(logs, hasLength(1));
    expect(logs.first['action'], 'product.created');
  });

  test('updates product price and details', () async {
    final p = makeProduct('p1', 'Sugar', 150);
    await repository.save(p);

    final updated = p.copyWith(
      details: ProductDetails.create(name: 'Sugar (Special)', unit: 'kg', unitPrice: const Money.rupees(170)),
      updatedAt: DateTime.utc(2026, 11, 19, 11, 0),
    );
    await repository.update(updated);

    final fetched = await repository.findById(shopId, 'p1');
    expect(fetched!.name, 'Sugar (Special)');
    expect(fetched.unitPrice.paisa, 17000);

    final logs = await db.executor.query('audit_log', where: 'action = ?', whereArgs: ['product.updated']);
    expect(logs, hasLength(1));
  });

  test('enforces shop tenant isolation', () async {
    await repository.save(makeProduct('p1', 'Shop 1 Oil', 500, targetShop: shopId));
    await repository.save(makeProduct('p2', 'Shop 2 Rice', 300, targetShop: otherShopId));

    expect(await repository.findById(shopId, 'p2'), isNull);
    expect(await repository.findById(otherShopId, 'p1'), isNull);

    final shop1List = await repository.listForShop(shopId);
    expect(shop1List.map((e) => e.id), ['p1']);
  });

  test('search filters products by name', () async {
    await repository.save(makeProduct('p1', 'Basmati Rice', 320));
    await repository.save(makeProduct('p2', 'Brown Rice', 280));
    await repository.save(makeProduct('p3', 'Dal Chana', 240));

    final searchRice = await repository.listForShop(shopId, searchQuery: 'rice');
    expect(searchRice.map((e) => e.name), ['Basmati Rice', 'Brown Rice']);
  });

  test('archiving hides product from active catalog without deleting', () async {
    await repository.save(makeProduct('p1', 'Seasonal Fruit', 200));

    final archiveTime = DateTime.utc(2026, 11, 19, 12, 0);
    await repository.setArchivedStatus(shopId, 'p1', archived: true, timestamp: archiveTime);

    final activeList = await repository.listForShop(shopId);
    expect(activeList, isEmpty);

    final allList = await repository.listForShop(shopId, includeArchived: true);
    expect(allList, hasLength(1));
    expect(allList.first.isArchived, isTrue);

    final record = await repository.findById(shopId, 'p1');
    expect(record, isNotNull);
    expect(record!.isArchived, isTrue);
  });

  test('implements ProductLookupPort correctly', () async {
    await repository.save(makeProduct('p1', 'Flour (Atta 10kg)', 1400, unit: 'sack'));

    final snapshot = await repository.findForShop(shopId: shopId, productId: 'p1');
    expect(snapshot, isNotNull);
    expect(snapshot!.id, 'p1');
    expect(snapshot.name, 'Flour (Atta 10kg)');
    expect(snapshot.unit, 'sack');
    expect(snapshot.unitPrice.paisa, 140000);
    expect(snapshot.isArchived, isFalse);
  });
}
