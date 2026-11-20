import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_transaction.dart';
import '../domain/auth_user.dart';

/// Persists active authentication session in SQLite `app_settings`
/// so sessions survive app restarts and users stay signed in.
final class LocalSessionStorage {
  const LocalSessionStorage(this._db);

  final DatabaseTransactionPort _db;

  static const String keyUid = 'session_uid';
  static const String keyPhone = 'session_phone';
  static const String keyName = 'session_name';
  static const String keyEmail = 'session_email';
  static const String keyRole = 'session_role';

  Future<void> saveSession({
    required String uid,
    String? phone,
    String? displayName,
    String? email,
    required String role,
  }) async {
    await _upsert(keyUid, uid);
    await _upsert(keyPhone, phone ?? '');
    await _upsert(keyName, displayName ?? '');
    await _upsert(keyEmail, email ?? '');
    await _upsert(keyRole, role);
  }

  Future<({AuthUser user, String role})?> loadSession() async {
    final rows = await _db.executor.query('app_settings');
    final map = <String, String>{};
    for (final r in rows) {
      final k = r['key'] as String;
      final v = r['value'] as String? ?? '';
      map[k] = v;
    }

    final uid = map[keyUid];
    if (uid == null || uid.isEmpty) return null;

    final phone = map[keyPhone];
    final name = map[keyName];
    final email = map[keyEmail];
    final role = map[keyRole] ?? 'shopkeeper';

    final user = AuthUser(
      uid: uid,
      phoneNumber: (phone != null && phone.isNotEmpty) ? phone : null,
      displayName: (name != null && name.isNotEmpty) ? name : 'Shopkeeper',
      email: (email != null && email.isNotEmpty) ? email : null,
      isEmailVerified: true,
    );

    return (user: user, role: role);
  }

  Future<void> clearSession() async {
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: [keyUid]);
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: [keyPhone]);
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: [keyName]);
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: [keyEmail]);
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: [keyRole]);
    await _db.executor.delete('app_settings', where: 'key = ?', whereArgs: ['active_shop_id']);
  }

  Future<void> _upsert(String key, String value) async {
    await _db.executor.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
