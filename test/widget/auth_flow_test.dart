import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/app/app_router.dart';
import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/auth/data/in_memory_auth_service.dart';
import 'package:easy_hisab/features/auth/presentation/auth_providers.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';

void main() {
  sqfliteFfiInit();

  group('Module 08: Auth Flow Widget Tests', () {
    late LocalDatabase db;
    late InMemoryAuthService inMemoryAuth;
    const idGen = UuidIdGenerator();

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      inMemoryAuth = InMemoryAuthService();

      // Seed a shop so shop dashboard works immediately
      final now = DateTime.utc(2026, 11, 19, 10, 0);
      final shopRepo = SqliteShopRepository(db, idGen);
      await shopRepo.createAndActivate(
        Shop(
          id: 'shop-1',
          details: ShopDetails.create(name: 'Tariq General Store'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() => db.close());

    Future<void> settleAsync(WidgetTester tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pumpAndSettle();
    }

    testWidgets('navigate from RoleChoice to Login, then Sign In', (tester) async {
      // Pre-seed an account in auth service
      await inMemoryAuth.registerWithEmail(
        'tariq@kiryana.pk',
        'password123',
        displayName: 'Tariq General Store',
      );
      await inMemoryAuth.signOut();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(inMemoryAuth),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.chooseRole),
        ),
      );
      await settleAsync(tester);

      // Verify Role Choice Screen has Sign In with Email button
      expect(find.text('Sign In with Email'), findsOneWidget);

      // Tap Sign In with Email
      await tester.tap(find.text('Sign In with Email'));
      await settleAsync(tester);

      // Verify on Login Screen
      expect(find.text('Welcome to EasyHisab'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'tariq@kiryana.pk',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.pump();

      // Tap Sign In
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await settleAsync(tester);

      // Assert user is signed in
      expect(inMemoryAuth.currentUser?.email, 'tariq@kiryana.pk');
    });

    testWidgets('can open Register screen and create new shopkeeper account', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(inMemoryAuth),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.login),
        ),
      );
      await settleAsync(tester);

      // Scroll and tap Register link
      final registerButton = find.widgetWithText(TextButton, 'Register');
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await settleAsync(tester);

      // Verify Register Screen
      expect(find.text('Join EasyHisab'), findsOneWidget);

      // Fill in registration form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name / Shop Name'),
        'Bilal Store',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'bilal@store.pk',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'secret123',
      );
      await tester.pump();

      // Tap Create Account
      final createBtn = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await settleAsync(tester);

      // Assert user registered and signed in
      expect(inMemoryAuth.currentUser?.email, 'bilal@store.pk');
      expect(inMemoryAuth.currentUser?.displayName, 'Bilal Store');
    });

    testWidgets('navigate from RoleChoice to Phone Login, send OTP and verify', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
            authServiceProvider.overrideWithValue(inMemoryAuth),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.chooseRole),
        ),
      );
      await settleAsync(tester);

      // Verify Role Choice Screen has Login with Mobile Number (OTP)
      expect(find.text('Login with Mobile Number (OTP)'), findsOneWidget);

      // Tap Login with Mobile Number
      await tester.tap(find.text('Login with Mobile Number (OTP)'));
      await settleAsync(tester);

      // Verify on Phone Login Screen
      expect(find.text('Phone Number Login'), findsOneWidget);
      expect(find.byKey(const Key('phone_number_field')), findsOneWidget);

      // Enter Pakistani phone number
      await tester.enterText(
        find.byKey(const Key('phone_number_field')),
        '03001234567',
      );
      await tester.pump();

      // Tap Send OTP Code
      await tester.tap(find.byKey(const Key('send_otp_button')));
      await settleAsync(tester);

      // Verify OTP entry step is shown
      expect(find.text('Enter SMS Code'), findsOneWidget);
      expect(find.byKey(const Key('otp_code_field')), findsOneWidget);

      // Enter 6-digit OTP code
      await tester.enterText(
        find.byKey(const Key('otp_code_field')),
        '123456',
      );
      await tester.pump();

      // Tap Verify & Continue
      await tester.tap(find.byKey(const Key('verify_otp_button')));
      await settleAsync(tester);

      // Assert user is authenticated with phone
      expect(inMemoryAuth.currentUser?.phoneNumber, '+923001234567');
    });
  });
}
