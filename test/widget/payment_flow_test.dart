import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:easy_hisab/features/customers/data/sqlite_customer_repository.dart';
import 'package:easy_hisab/features/customers/domain/customer.dart';
import 'package:easy_hisab/features/sales/data/sqlite_sale_repository.dart';
import 'package:easy_hisab/features/sales/domain/sale.dart';
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

    // Seed Rs 2,500 credit sale
    final saleRepo = SqliteSaleRepository(db, idGen);
    await saleRepo.savePendingSale(
      Sale(
        id: 'sale-1',
        shopId: shopId,
        customerId: customerId,
        receiptNo: 'R-0001',
        saleType: SaleType.credit,
        total: const Money.rupees(2500),
        createdAt: now,
        items: [
          SaleLine.create(
            id: 'l1',
            saleId: 'sale-1',
            description: 'Sugar',
            unit: 'kg',
            quantity: const Quantity.whole(2),
            unitPrice: const Money.rupees(150), // 300
            position: 0,
          ),
          SaleLine.create(
            id: 'l2',
            saleId: 'sale-1',
            description: 'Cooking Oil',
            unit: 'ltr',
            quantity: const Quantity.whole(4),
            unitPrice: const Money.rupees(550), // 2200
            position: 1,
          ),
        ],
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
      'Module 06 acceptance gate: record Rs 1000 repayment for Rs 2500 udhar, inspect ledger, verify Rs 1500 balance & reverse',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // 1. Dashboard shows Receive Money tile -> tap it
    expect(find.text('Receive Money'), findsOneWidget);
    await tester.tap(find.text('Receive Money'));
    await settleAsync(tester);

    // 2. We are on Receive Repayment screen
    expect(find.text('Receive Repayment'), findsOneWidget);

    // 3. Select Customer
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settleAsync(tester);
    await tester.tap(find.textContaining('Tariq Mehmood').last);
    await settleAsync(tester);

    // 4. Verify current balance shows Rs 2,500
    expect(find.text('Current Udhar Due:'), findsOneWidget);
    expect(find.text('Rs 2,500'), findsOneWidget);

    // 5. Enter repayment amount: 1000
    final amountField = find.widgetWithText(TextFormField, 'Amount Received (PKR) *');
    await tester.enterText(amountField, '1000');
    await tester.pump();

    // 6. Verify projected remaining due shows Rs 1,500
    expect(find.text('Projected Remaining Due:'), findsOneWidget);
    expect(find.text('Rs 1,500'), findsOneWidget);
    expect(find.text('Record Payment (Rs 1,000)'), findsOneWidget);

    // 7. Tap Record Payment
    await tester.tap(find.text('Record Payment (Rs 1,000)'));
    await settleAsync(tester);

    // 8. Go to Customer Details
    // If not already on customer detail, navigate via Customers -> Tariq Mehmood
    if (find.text('Customer Details').evaluate().isEmpty) {
      if (find.text('Customers').evaluate().isNotEmpty) {
        await tester.tap(find.text('Customers'));
        await settleAsync(tester);
      }
      if (find.text('Tariq Mehmood').evaluate().isNotEmpty) {
        await tester.tap(find.text('Tariq Mehmood'));
        await settleAsync(tester);
      }
    }

    expect(find.text('Customer Details'), findsOneWidget);
    expect(find.text('Tariq Mehmood'), findsOneWidget);

    // 9. Outstanding Udhar card must show Rs 1,500
    expect(find.text('Outstanding Udhar'), findsOneWidget);
    expect(find.text('Rs 1,500'), findsOneWidget);

    // 10. Khata Ledger Timeline shows credit bill and payment
    expect(find.text('Khata Ledger Timeline'), findsOneWidget);
    expect(find.textContaining('Credit Bill #R-0001'), findsOneWidget);
    expect(find.textContaining('Payment received'), findsOneWidget);
    expect(find.text('+ Rs 2,500'), findsOneWidget);
    expect(find.text('- Rs 1,000'), findsOneWidget);

    // 11. Tap on the payment entry in the timeline to reverse it
    await tester.tap(find.textContaining('Payment received'));
    await settleAsync(tester);

    expect(find.text('Reverse Payment?'), findsOneWidget);
    final reasonField = find.byType(TextField);
    await tester.enterText(reasonField, 'Customer gave wrong amount');
    await tester.tap(find.text('Confirm Reversal'));
    await settleAsync(tester);

    // 12. Payment is now marked REVERSED and Outstanding Udhar restores to Rs 2,500!
    expect(find.text('REVERSED'), findsOneWidget);
    expect(find.text('Rs 2,500'), findsWidgets);
  });

  testWidgets(
      'Navigating from customer details opens receive payment with customer pre-selected',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // Go to customer details
    await tester.tap(find.text('Customers'));
    await settleAsync(tester);
    await tester.tap(find.text('Tariq Mehmood'));
    await settleAsync(tester);

    // Tap Receive Payment button
    expect(find.text('Receive Payment'), findsOneWidget);
    await tester.tap(find.text('Receive Payment'));
    await settleAsync(tester);

    // Customer should already be pre-selected on Receive Repayment screen
    expect(find.text('Receive Repayment'), findsOneWidget);
    expect(find.textContaining('Tariq Mehmood'), findsOneWidget);
    expect(find.text('Current Udhar Due:'), findsOneWidget);
  });
}
