import 'package:sqflite/sqflite.dart';

/// Version 2: small key/value table for local app state such as the
/// currently active shop.
Future<void> migration002(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE app_settings (
      key    TEXT PRIMARY KEY,
      value  TEXT
    )''');
}
