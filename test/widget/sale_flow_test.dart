import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/customers/data/sqlite_customer_repository.dart';
import 'package:easy_hisab/features/customers/domain/customer.dart';
import 'package:easy_hisab/features/products/data/sqlite_product_repository.dart';
import 'package:easy_hisab/features/products/domain/product.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  const idGen = UuidIdGenerator();
  const shopId = 'shop-1';
  const customerId = 'cust-1';

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );

    final now = DateTime.utc(2026, 11, 20, 10, 0);

    // Seed active shop
    final shopRepo = SqliteShopRepository(db, idGen);
    await shopRepo.createAndActivate(
      Shop(
        id: shopId,
        details: ShopDetails.create(name: 'Madina Store'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Seed customer
    final custRepo = SqliteCustomerRepository(db, idGen);
    await custRepo.save(
      Customer(
        id: customerId,
        shopId: shopId,
        details: CustomerDetails.create(
          name: 'Tariq Mehmood',
          phone: '+923001234567',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Seed products
    final prodRepo = SqliteProductRepository(db, idGen);
    await prodRepo.save(
      Product(
        id: 'prod-sugar',
        shopId: shopId,
        details: ProductDetails.create(
          name: 'Sugar',
          unit: 'kg',
          unitPrice: const Money.rupees(150),
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await prodRepo.save(
      Product(
        id: 'prod-oil',
        shopId: shopId,
        details: ProductDetails.create(
          name: 'Cooking Oil',
          unit: 'ltr',
          unitPrice: const Money.rupees(550),
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => db.close());

  Widget buildTestApp({String initialLocation = '/shop/dashboard'}) {
    return ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
      ],
      child: EasyHisabApp(initialLocation: initialLocation),
    );
  }

  Future<void> settleAsync(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Module 05 acceptance gate: create credit sale, add products, post Rs 2500 bill, inspect receipt & reverse',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // 1. Dashboard shows New Bill action tile -> tap it
    expect(find.text('New Bill'), findsOneWidget);
    await tester.tap(find.text('New Bill'));
    await settleAsync(tester);

    // 2. We are on Create New Bill screen
    expect(find.text('Create New Bill'), findsOneWidget);

    // 3. Select Customer
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settleAsync(tester);
    await tester.tap(find.textContaining('Tariq Mehmood').last);
    await settleAsync(tester);

    // 4. Add First Product: Cooking Oil (first alphabetically: unit ltr, Rs 550)
    await tester.tap(find.text('Add Product'));
    await settleAsync(tester);

    expect(find.text('Add Item to Cart'), findsOneWidget);
    // Cooking Oil is first; enter qty 4 -> Rs 2,200
    final oilQtyField = find.widgetWithText(TextFormField, 'Quantity (ltr)');
    await tester.enterText(oilQtyField, '4');
    await tester.tap(find.text('Add to Bill'));
    await settleAsync(tester);

    // 5. Add Second Product: Sugar (change dropdown to Sugar: unit kg, Rs 150)
    await tester.tap(find.text('Add Product'));
    await settleAsync(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Product>));
    await settleAsync(tester);
    await tester.tap(find.textContaining('Sugar').last);
    await settleAsync(tester);

    final sugarQtyField = find.widgetWithText(TextFormField, 'Quantity (kg)');
    await tester.enterText(sugarQtyField, '2');
    await tester.tap(find.text('Add to Bill'));
    await settleAsync(tester);

    // 6. Verify total shows Rs 2,500
    expect(find.text('Rs 2,500'), findsWidgets);
    expect(find.text('Post Credit Bill (Rs 2,500)'), findsOneWidget);

    // 7. Post the credit bill
    await tester.tap(find.text('Post Credit Bill (Rs 2,500)'));
    await settleAsync(tester);

    // 8. We should be redirected to SaleDetailScreen
    expect(find.text('R-0001'), findsWidgets);
    expect(find.textContaining('Tariq Mehmood'), findsWidgets);
    expect(find.textContaining('Pending Cloud Sync'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
    expect(find.text('Itemized Purchased Products'), findsOneWidget);
    expect(find.text('Cooking Oil'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);
    expect(find.text('Reverse Bill'), findsOneWidget);

    // 9. Reverse the bill
    await tester.tap(find.text('Reverse Bill'));
    await settleAsync(tester);

    expect(find.text('Reverse Bill?'), findsOneWidget);
    final reasonField = find.byType(TextField);
    await tester.enterText(reasonField, 'Customer returned products');
    await tester.tap(find.text('Confirm Reversal'));
    await settleAsync(tester);

    // 10. Status updates to Reversed
    expect(find.text('Reversed'), findsOneWidget);
  });

  testWidgets(
      'Navigating from customer detail pre-selects the customer for new bill',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // Navigate to customers list
    await tester.tap(find.text('Customers'));
    await settleAsync(tester);

    // Open Tariq Mehmood details
    expect(find.text('Tariq Mehmood'), findsOneWidget);
    await tester.tap(find.text('Tariq Mehmood'));
    await settleAsync(tester);

    // Tap New Bill button on customer details
    expect(find.text('New Bill'), findsOneWidget);
    await tester.tap(find.text('New Bill'));
    await settleAsync(tester);

    // Customer should already be preselected in NewSaleScreen
    expect(find.text('Create New Bill'), findsOneWidget);
    expect(find.textContaining('Tariq Mehmood'), findsOneWidget);
  });
}
