import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
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

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );

    // Seed active shop
    final now = DateTime.utc(2026, 11, 19, 10, 0);
    final shopRepo = SqliteShopRepository(db, idGen);
    await shopRepo.createAndActivate(
      Shop(
        id: 'shop-1',
        details: ShopDetails.create(name: 'Madina Store'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => db.close());

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
      ],
      child: const EasyHisabApp(initialLocation: '/shop/dashboard'),
    );
  }

  Future<void> settleAsync(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Module 04 acceptance gate: add products, search, edit price, and archive',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // 1. Dashboard -> tap Products
    expect(find.text('Products'), findsOneWidget);
    await tester.tap(find.text('Products'));
    await settleAsync(tester);

    // 2. Empty catalog view
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.text('No Products in Catalog'), findsOneWidget);

    // Helper to add a product
    Future<void> addProduct(String name, String priceRupees) async {
      await tester.tap(find.byType(FloatingActionButton));
      await settleAsync(tester);

      expect(find.text('Add New Product'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Name *'),
        name,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Unit Price (Rupees) *'),
        priceRupees,
      );

      await tester.tap(find.text('Save Product'));
      await settleAsync(tester);
    }

    // 3. Add products: Sugar @ 150/kg, Cooking Oil @ 520, Basmati Rice @ 340
    await addProduct('White Sugar', '150');
    await addProduct('Cooking Oil', '520');
    await addProduct('Basmati Rice', '340');

    expect(find.text('White Sugar'), findsOneWidget);
    expect(find.text('Cooking Oil'), findsOneWidget);
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Rs 150'), findsOneWidget);

    // 4. Search for "Sugar"
    await tester.enterText(find.byType(SearchBar), 'sugar');
    await settleAsync(tester);

    expect(find.text('White Sugar'), findsOneWidget);
    expect(find.text('Cooking Oil'), findsNothing);

    // 5. Tap White Sugar to Edit Price: Rs 150/kg -> Rs 170/kg
    await tester.tap(find.text('White Sugar'));
    await settleAsync(tester);

    expect(find.text('Edit Product'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unit Price (Rupees) *'),
      '170',
    );
    await tester.tap(find.text('Save Changes'));
    await settleAsync(tester);

    // Verify catalog reflects new price Rs 170
    expect(find.text('Rs 170'), findsOneWidget);

    // 6. Archive White Sugar
    await tester.tap(find.text('White Sugar'));
    await settleAsync(tester);

    await tester.tap(find.byTooltip('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archive Product?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await settleAsync(tester);

    // 7. Verify White Sugar is hidden from active catalog
    await tester.enterText(find.byType(SearchBar), '');
    await settleAsync(tester);

    expect(find.text('White Sugar'), findsNothing);
    expect(find.text('Cooking Oil'), findsOneWidget);

    // 8. Toggle "Include Archived"
    await tester.tap(find.text('Include Archived'));
    await settleAsync(tester);

    expect(find.text('White Sugar'), findsOneWidget);
  });
}
