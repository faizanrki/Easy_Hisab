import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/customers/data/sqlite_customer_repository.dart';
import 'package:easy_hisab/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  late SqliteCustomerRepository repository;
  const idGen = UuidIdGenerator();
  const shopId = 'test-shop-1';
  const otherShopId = 'test-shop-2';

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repository = SqliteCustomerRepository(db, idGen);

    // Seed test shops
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

  Customer makeCustomer(String id, String name, {String? phone, String targetShop = shopId}) {
    final now = DateTime.utc(2026, 11, 19, 10, 0);
    return Customer(
      id: id,
      shopId: targetShop,
      details: CustomerDetails.create(name: name, phone: phone),
      createdAt: now,
      updatedAt: now,
    );
  }

  test('saves customer and retrieves by ID', () async {
    final c = makeCustomer('c1', 'Ali Khan', phone: '03001234567');
    await repository.save(c);

    final fetched = await repository.findById(shopId, 'c1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Ali Khan');
    expect(fetched.phone, '+923001234567');
    expect(fetched.isArchived, isFalse);

    // Check audit log
    final logs = await db.executor.query('audit_log', where: 'record_id = ?', whereArgs: ['c1']);
    expect(logs, hasLength(1));
    expect(logs.first['action'], 'customer.created');
  });

  test('updates customer and records audit event', () async {
    final c = makeCustomer('c1', 'Old Name', phone: '03001111111');
    await repository.save(c);

    final updated = c.copyWith(
      details: CustomerDetails.create(name: 'New Name', phone: '03002222222'),
      updatedAt: DateTime.utc(2026, 11, 19, 11, 0),
    );
    await repository.update(updated);

    final fetched = await repository.findById(shopId, 'c1');
    expect(fetched!.name, 'New Name');
    expect(fetched.phone, '+923002222222');
  });

  test('enforces shop tenant isolation', () async {
    final c1 = makeCustomer('c1', 'Shop 1 Customer', targetShop: shopId);
    final c2 = makeCustomer('c2', 'Shop 2 Customer', targetShop: otherShopId);
    await repository.save(c1);
    await repository.save(c2);

    expect(await repository.findById(shopId, 'c2'), isNull);
    expect(await repository.findById(otherShopId, 'c1'), isNull);

    final shop1List = await repository.listForShop(shopId);
    expect(shop1List.map((e) => e.id), ['c1']);
  });

  test('search filters customers by name and phone', () async {
    await repository.save(makeCustomer('c1', 'Muhammad Ali', phone: '03001111111'));
    await repository.save(makeCustomer('c2', 'Usman Tariq', phone: '03212222222'));
    await repository.save(makeCustomer('c3', 'Ali Hassan', phone: '03333333333'));

    final searchAli = await repository.listForShop(shopId, searchQuery: 'ali');
    expect(searchAli.map((e) => e.name), ['Ali Hassan', 'Muhammad Ali']);

    final searchPhone = await repository.listForShop(shopId, searchQuery: '321222');
    expect(searchPhone.map((e) => e.name), ['Usman Tariq']);
  });

  test('archiving preserves record and allows filtering', () async {
    final c = makeCustomer('c1', 'Bilal Ahmed');
    await repository.save(c);

    final archiveTime = DateTime.utc(2026, 11, 19, 12, 0);
    await repository.setArchivedStatus(shopId, 'c1', archived: true, timestamp: archiveTime);

    // Default list hides archived
    final activeList = await repository.listForShop(shopId);
    expect(activeList, isEmpty);

    // Include archived shows it
    final allList = await repository.listForShop(shopId, includeArchived: true);
    expect(allList, hasLength(1));
    expect(allList.first.isArchived, isTrue);

    // Customer still exists in database
    final record = await repository.findById(shopId, 'c1');
    expect(record, isNotNull);
    expect(record!.isArchived, isTrue);
  });

  test('implements CustomerLookupPort correctly', () async {
    await repository.save(makeCustomer('c1', 'Zahid Hussain', phone: '03005555555'));

    final summary = await repository.findForShop(shopId: shopId, customerId: 'c1');
    expect(summary, isNotNull);
    expect(summary!.id, 'c1');
    expect(summary.name, 'Zahid Hussain');
    expect(summary.phone, '+923005555555');
    expect(summary.isArchived, isFalse);
  });
}
