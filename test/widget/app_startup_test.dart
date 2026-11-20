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

  testWidgets('starts on role choice and opens each experience',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EasyHisab'), findsOneWidget);
    expect(find.text('I am a Shopkeeper'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);

    await tester.tap(find.text('I am a Shopkeeper'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Shop Dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('I am a Customer'), findsOneWidget);
    await tester.tap(find.text('I am a Customer'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Customer Hisaab Portal'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
