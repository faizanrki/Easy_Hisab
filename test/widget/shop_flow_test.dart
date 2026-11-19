import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/features/auth/data/in_memory_auth_service.dart';
import 'package:easy_hisab/features/auth/domain/auth_user.dart';
import 'package:easy_hisab/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(
          InMemoryAuthService(
            initialUser: const AuthUser(
              uid: 'test_shopkeeper',
              phoneNumber: '+923001234567',
              displayName: 'Test Shopkeeper',
              isEmailVerified: true,
            ),
          ),
        ),
      ],
      child: const EasyHisabApp(),
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
      'flow: start -> role choice -> setup shop -> dashboard reflects shop',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // 1. Choose Shopkeeper
    await tester.tap(find.text('I am a Shopkeeper'));
    await settleAsync(tester);

    // 2. Since no shop exists, empty state is shown
    expect(find.text('No Shop Configured Yet'), findsOneWidget);
    expect(find.text('Set Up Shop Now'), findsOneWidget);

    // 3. Tap to Set up shop
    await tester.tap(find.text('Set Up Shop Now'));
    await tester.pumpAndSettle();

    expect(find.text('Shop Setup'), findsOneWidget);

    // 4. Fill form
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Shop Name *'),
      'Madina Super Store',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contact Phone'),
      '03001234567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Chowk Yadgar, Peshawar',
    );

    // 5. Submit
    await tester.tap(find.text('Save and Continue'));
    await settleAsync(tester);

    // 6. Should navigate to dashboard with shop details
    expect(find.text('Madina Super Store'), findsAtLeastNWidgets(1));
    expect(find.text('+923001234567'), findsOneWidget);
    expect(find.text('Chowk Yadgar, Peshawar'), findsOneWidget);
    expect(find.text('Local store (unverified)'), findsOneWidget);
  });
}
