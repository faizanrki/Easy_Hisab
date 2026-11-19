import 'package:sqflite/sqflite.dart';

/// Runs a unit of work atomically: either every write commits, or none do.
///
/// Feature repositories depend on this port (not on a global raw database),
/// e.g. to save a sale + its items + an outbox row together.
abstract interface class DatabaseTransactionPort {
  Future<T> inTransaction<T>(Future<T> Function(DatabaseExecutor tx) action);

  /// Executor for simple reads / single-statement writes.
  DatabaseExecutor get executor;
}
