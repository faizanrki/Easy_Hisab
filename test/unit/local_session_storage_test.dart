import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/features/auth/data/local_session_storage.dart';

void main() {
  sqfliteFfiInit();

  group('LocalSessionStorage Unit Tests', () {
    late LocalDatabase db;
    late LocalSessionStorage storage;

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      storage = LocalSessionStorage(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('loads null when no session is saved', () async {
      final session = await storage.loadSession();
      expect(session, isNull);
    });

    test('saves, loads, and preserves shopkeeper session', () async {
      await storage.saveSession(
        uid: 'user_shopkeeper_99',
        phone: '+923001234567',
        displayName: 'Haji Aslam',
        email: 'aslam@store.pk',
        role: 'shopkeeper',
      );

      final session = await storage.loadSession();
      expect(session, isNotNull);
      expect(session!.user.uid, equals('user_shopkeeper_99'));
      expect(session.user.phoneNumber, equals('+923001234567'));
      expect(session.user.displayName, equals('Haji Aslam'));
      expect(session.role, equals('shopkeeper'));
    });

    test('clearSession removes all session keys', () async {
      await storage.saveSession(
        uid: 'user_cust_1',
        phone: '+923451122334',
        role: 'customer',
      );

      expect(await storage.loadSession(), isNotNull);

      await storage.clearSession();
      expect(await storage.loadSession(), isNull);
    });
  });
}
