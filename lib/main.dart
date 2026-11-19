import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/dependency_providers.dart';
import 'app/easy_hisab_app.dart';
import 'core/database/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.open();

  runApp(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: const EasyHisabApp(),
    ),
  );
}
