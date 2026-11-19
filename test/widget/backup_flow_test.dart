import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/app/app_router.dart';
import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';

void main() {
  sqfliteFfiInit();

  group('Module 12: Backup Flow Widget Tests', () {
    late LocalDatabase db;
    const idGen = UuidIdGenerator();
    const shopId = 'shop_backup_test';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      final now = DateTime.utc(2026, 11, 19, 10, 0);
      final shopRepo = SqliteShopRepository(db, idGen);
      await shopRepo.createAndActivate(
        Shop(
          id: shopId,
          details: ShopDetails.create(name: 'Backup Test Shop'),
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

    testWidgets('creates a local backup snapshot and verifies history entry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.backup),
        ),
      );
      await settleAsync(tester);

      // Verify screen title and initial empty history
      expect(find.text('Database Backup & Restore'), findsOneWidget);
      expect(find.text('No backups created yet.'), findsOneWidget);

      // Tap Create Backup Now
      await tester.tap(find.widgetWithText(FilledButton, 'Create Backup Now'));
      await settleAsync(tester);

      // Verify snackbar
      expect(find.textContaining('Backup created successfully!'), findsOneWidget);

      // Verify history now displays entry with schema version
      expect(find.textContaining('Schema v1'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  });
}
