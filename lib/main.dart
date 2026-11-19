import 'package:cloud_firestore/cloud_firestore.dart' as fb_store;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/dependency_providers.dart';
import 'app/easy_hisab_app.dart';
import 'core/database/local_database.dart';
import 'features/auth/data/firebase_auth_service.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/sync/data/firestore_cloud_sync_remote.dart';
import 'features/sync/presentation/sync_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.open();

  final overrides = [
    localDatabaseProvider.overrideWithValue(database),
  ];

  try {
    await Firebase.initializeApp();
    overrides.addAll([
      authServiceProvider.overrideWithValue(
        FirebaseAuthService(fb_auth.FirebaseAuth.instance),
      ),
      cloudSyncRemoteProvider.overrideWithValue(
        FirestoreCloudSyncRemote(fb_store.FirebaseFirestore.instance),
      ),
    ]);
  } catch (e) {
    debugPrint('Firebase initialization fallback to in-memory: $e');
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const EasyHisabApp(),
    ),
  );
}
