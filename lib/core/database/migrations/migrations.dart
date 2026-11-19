import 'package:sqflite/sqflite.dart';

import 'migration_001.dart';
import 'migration_002.dart';

typedef Migration = Future<void> Function(DatabaseExecutor db);

/// Ordered list of schema migrations. Index 0 upgrades to version 1, etc.
///
/// Never edit a migration that has shipped; append a new one instead.
const List<Migration> migrations = [
  migration001,
  migration002,
];

int get latestSchemaVersion => migrations.length;
