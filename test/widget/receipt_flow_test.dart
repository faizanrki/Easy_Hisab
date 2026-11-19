import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:easy_hisab/features/customers/data/sqlite_customer_repository.dart';
import 'package:easy_hisab/features/customers/domain/customer.dart';
import 'package:easy_hisab/features/products/data/sqlite_product_repository.dart';
import 'package:easy_hisab/features/products/domain/product.dart';
import 'package:easy_hisab/features/sales/data/sqlite_sale_repository.dart';
import 'package:easy_hisab/features/sales/domain/sale.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  const idGen = UuidIdGenerator();
  const shopId = 'shop-1';
  const customerId = 'cust-1';
  const productId = 'prod-sugar';

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
        details: ShopDetails.create(
          name: 'Madina Store',
          address: 'Bazar Road',
          contactPhone: '+923001234567',
        ),
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
          phone: '+923009876543',
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Seed product: Sugar @ Rs 150/kg
    final prodRepo = SqliteProductRepository(db, idGen);
    await prodRepo.save(
      Product(
        id: productId,
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

    // Post Sale: 2 kg Sugar @ Rs 150 = Rs 300
    final saleRepo = SqliteSaleRepository(db, idGen);
    await saleRepo.savePendingSale(
      Sale(
        id: 'sale-100',
        shopId: shopId,
        customerId: customerId,
        receiptNo: 'R-0001',
        saleType: SaleType.credit,
        total: const Money.rupees(300),
        createdAt: now,
        items: [
          SaleLine.create(
            id: 'l1',
            saleId: 'sale-100',
            productId: productId,
            description: 'Sugar',
            unit: 'kg',
            quantity: const Quantity.whole(2),
            unitPrice: const Money.rupees(150),
            position: 0,
          ),
        ],
      ),
    );

    // UPDATE Catalog price: Sugar price changes from Rs 150 to Rs 180
    await prodRepo.update(
      Product(
        id: productId,
        shopId: shopId,
        details: ProductDetails.create(
          name: 'Sugar',
          unit: 'kg',
          unitPrice: const Money.rupees(180),
        ),
        createdAt: now,
        updatedAt: DateTime.utc(2026, 11, 20, 11, 0),
      ),
    );
  });

  tearDown(() => db.close());

  Widget buildTestApp({String initialLocation = '/shop/sales/sale-100'}) {
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
      'Module 07 acceptance gate: reopen older receipt after catalog price changes, values match original snapshot and PDF preview shares',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // 1. We are on SaleDetailScreen for sale-100
    expect(find.text('R-0001'), findsWidgets);
    expect(find.textContaining('Tariq Mehmood'), findsWidgets);

    // Verify historical snapshot: still displays Rs 300 (not updated Rs 360)
    expect(find.text('Rs 300'), findsWidgets);
    expect(find.text('Sugar'), findsOneWidget);

    // 2. Tap Share Receipt button
    expect(find.text('Share Receipt'), findsOneWidget);
    await tester.tap(find.text('Share Receipt'));
    await settleAsync(tester);

    // 3. We are on ReceiptPreviewScreen
    expect(find.text('Receipt #R-0001'), findsOneWidget);

    // 4. WhatsApp quick share button is present for customer
    expect(
      find.text('Send to Tariq Mehmood on WhatsApp'),
      findsOneWidget,
    );

    // 5. PdfPreview widget is active
    expect(find.byType(PdfPreview), findsOneWidget);
  });
}
