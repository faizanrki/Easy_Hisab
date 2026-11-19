import 'dart:convert';
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
import 'package:easy_hisab/features/sync/data/in_memory_cloud_sync_remote.dart';
import 'package:easy_hisab/features/sync/presentation/sync_providers.dart';

void main() {
  sqfliteFfiInit();

  group('Module 10: Sync Flow Widget Tests', () {
    late LocalDatabase db;
    late InMemoryCloudSyncRemote inMemoryRemote;
    const idGen = UuidIdGenerator();
    const shopId = 'shop_sync_test';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      inMemoryRemote = InMemoryCloudSyncRemote();

      // Seed active shop
      final now = DateTime.utc(2026, 11, 19, 10, 0);
      final shopRepo = SqliteShopRepository(db, idGen);
      await shopRepo.createAndActivate(
        Shop(
          id: shopId,
          details: ShopDetails.create(name: 'Madina Super Store'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed 2 queued operations in sync_queue
      final nowMs = now.millisecondsSinceEpoch;
      await db.executor.insert('sync_queue', {
        'operation_id': 'op_1',
        'shop_id': shopId,
        'entity_type': 'customer',
        'entity_id': 'cust_1',
        'operation': 'insert',
        'payload': jsonEncode({'id': 'cust_1', 'name': 'Kashif'}),
        'sync_status': 'pending',
        'attempts': 0,
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      await db.executor.insert('sync_queue', {
        'operation_id': 'op_2',
        'shop_id': shopId,
        'entity_type': 'product',
        'entity_id': 'prod_1',
        'operation': 'insert',
        'payload': jsonEncode({'id': 'prod_1', 'name': 'Sugar'}),
        'sync_status': 'pending',
        'attempts': 0,
        'created_at': nowMs,
        'updated_at': nowMs,
      });
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

    testWidgets('displays pending changes in app bar and syncs to cloud on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
            cloudSyncRemoteProvider.overrideWithValue(inMemoryRemote),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.shopDashboard),
        ),
      );
      await settleAsync(tester);

      // Verify dashboard loaded
      expect(find.text('Madina Super Store'), findsAtLeastNWidgets(1));

      // Find pending changes icon/tooltip
      final syncButton = find.byTooltip('2 pending changes. Tap to sync.');
      expect(syncButton, findsOneWidget);

      // Tap sync button
      await tester.tap(syncButton);
      await settleAsync(tester);

      // Verify sync completed: remote received both documents
      expect(
        inMemoryRemote.getEntity(
          shopId: shopId,
          entityType: 'customer',
          entityId: 'cust_1',
        ),
        isNotNull,
      );
      expect(
        inMemoryRemote.getEntity(
          shopId: shopId,
          entityType: 'product',
          entityId: 'prod_1',
        ),
        isNotNull,
      );

      // Verify app bar now shows "Cloud Synced"
      expect(find.byTooltip('Cloud Synced'), findsOneWidget);
    });
  });
}
