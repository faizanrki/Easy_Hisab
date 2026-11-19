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

    // Seed active shop so we go straight to dashboard
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
      'Module 03 acceptance gate: create customers offline, search, view, edit and archive',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await settleAsync(tester);

    // 1. Dashboard shows Customers tile -> tap it
    expect(find.text('Customers'), findsOneWidget);
    await tester.tap(find.text('Customers'));
    await settleAsync(tester);

    // 2. Empty customer list view is displayed
    expect(find.text('Customer Khata'), findsOneWidget);
    expect(find.text('No Customers Yet'), findsOneWidget);

    // Helper to add a customer
    Future<void> addCustomer(String name, String phone) async {
      await tester.tap(find.byType(FloatingActionButton));
      await settleAsync(tester);

      expect(find.text('Add New Customer'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Customer Name *'),
        name,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number'),
        phone,
      );

      await tester.tap(find.text('Save Customer'));
      await settleAsync(tester);
    }

    // 3. Create 5 customers offline without requiring them to have an account
    await addCustomer('Ali Khan', '03001111111');
    await addCustomer('Bilal Ahmed', '03002222222');
    await addCustomer('Chaudhry Tariq', '03003333333');
    await addCustomer('Danish Malik', '03004444444');
    await addCustomer('Ehsan Ullah', '03005555555');

    // 4. Verify customers are in the list
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('Chaudhry Tariq'), findsOneWidget);
    expect(find.text('Danish Malik'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await settleAsync(tester);
    expect(find.text('Ehsan Ullah'), findsOneWidget);

    // 5. Search for "Tariq"
    await tester.enterText(find.byType(SearchBar), 'tariq');
    await settleAsync(tester);

    expect(find.text('Chaudhry Tariq'), findsOneWidget);
    expect(find.text('Ali Khan'), findsNothing);

    // 6. Tap on Chaudhry Tariq to view detail
    await tester.tap(find.text('Chaudhry Tariq'));
    await settleAsync(tester);

    expect(find.text('Customer Details'), findsOneWidget);
    expect(find.text('Chaudhry Tariq'), findsOneWidget);
    expect(find.text('+923003333333'), findsOneWidget);

    // 7. Edit customer name to "Chaudhry Tariq Javed"
    await tester.tap(find.byTooltip('Edit'));
    await settleAsync(tester);

    expect(find.text('Edit Customer'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer Name *'),
      'Chaudhry Tariq Javed',
    );
    await tester.tap(find.text('Save Changes'));
    await settleAsync(tester);

    // Detail screen reflects new name
    expect(find.text('Chaudhry Tariq Javed'), findsOneWidget);

    // 8. Archive customer
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Archive Customer?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await settleAsync(tester);

    expect(find.text('Archived Customer'), findsOneWidget);

    // 9. Go back to list -> Chaudhry Tariq is archived and hidden from active list
    await tester.pageBack();
    await settleAsync(tester);

    // Clear search
    await tester.enterText(find.byType(SearchBar), '');
    await settleAsync(tester);

    expect(find.text('Chaudhry Tariq Javed'), findsNothing);
    expect(find.text('Ali Khan'), findsOneWidget);

    // Toggle "Include Archived"
    await tester.tap(find.text('Include Archived'));
    await settleAsync(tester);

    expect(find.text('Chaudhry Tariq Javed'), findsOneWidget);
  });
}
