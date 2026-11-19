import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_transaction.dart';
import 'migrations/migrations.dart';

/// Owns the lifecycle of the on-device SQLite database.
///
/// * Enables foreign keys on every connection.
/// * Creates / upgrades the schema by running [migrations] in order.
final class LocalDatabase implements DatabaseTransactionPort {
  LocalDatabase._(this._db);

  final Database _db;

  static const String fileName = 'easy_hisab.db';

  /// Opens the app database in the platform databases directory.
  static Future<LocalDatabase> open({DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dir = await f.getDatabasesPath();
    return openAt(p.join(dir, fileName), factory: f);
  }

  /// Opens (or creates) a database at [path]. Tests pass
  /// [inMemoryDatabasePath] together with the FFI factory.
  static Future<LocalDatabase> openAt(
    String path, {
    DatabaseFactory? factory,
    int? version,
  }) async {
    final f = factory ?? databaseFactory;
    final target = version ?? latestSchemaVersion;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: target,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, newVersion) => _migrate(db, 0, newVersion),
        onUpgrade: _migrate,
      ),
    );
    return LocalDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await migrations[v](db);
    }
  }

  @override
  DatabaseExecutor get executor => _db;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(DatabaseExecutor tx) action,
  ) =>
      _db.transaction(action);

  Future<int> schemaVersion() => _db.getVersion();

  Future<void> close() => _db.close();
}
