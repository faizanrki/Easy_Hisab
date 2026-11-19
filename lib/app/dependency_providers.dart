import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/db_transaction.dart';
import '../core/database/local_database.dart';
import '../core/domain/clock.dart';
import '../core/domain/entity_id.dart';

/// Composition root: the ONLY place concrete implementations are chosen.
/// Screens and use cases receive these through providers, never by `new`.

/// Opened in `main()` before `runApp` and supplied via a ProviderScope override.
final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError('localDatabaseProvider must be overridden'),
);

final dbTransactionProvider = Provider<DatabaseTransactionPort>(
  (ref) => ref.watch(localDatabaseProvider),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidIdGenerator(),
);
