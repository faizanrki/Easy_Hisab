import 'package:cloud_firestore/cloud_firestore.dart' as fb_store;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_router.dart';
import 'app/dependency_providers.dart';
import 'app/easy_hisab_app.dart';
import 'core/database/local_database.dart';
import 'features/auth/data/firebase_auth_service.dart';
import 'features/auth/data/in_memory_auth_service.dart';
import 'features/auth/data/local_session_storage.dart';
import 'features/auth/domain/auth_service_port.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/sync/data/firestore_cloud_sync_remote.dart';
import 'features/sync/presentation/sync_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.open();

  final sessionStorage = LocalSessionStorage(database);
  final savedSession = await sessionStorage.loadSession();

  String initialLocation = AppRoutes.chooseRole;
  if (savedSession != null) {
    initialLocation = savedSession.role == 'customer'
        ? AppRoutes.customerShops
        : AppRoutes.shopDashboard;
  }

  final overrides = [
    localDatabaseProvider.overrideWithValue(database),
  ];

  AuthServicePort authService = InMemoryAuthService(
    initialUser: savedSession?.user,
  );

  try {
    await Firebase.initializeApp();
    authService = FirebaseAuthService(
      fb_auth.FirebaseAuth.instance,
      fallbackUser: savedSession?.user,
    );
    overrides.add(
      cloudSyncRemoteProvider.overrideWithValue(
        FirestoreCloudSyncRemote(fb_store.FirebaseFirestore.instance),
      ),
    );
  } catch (e) {
    debugPrint('Firebase initialization fallback to in-memory: $e');
  }

  // If Firebase persisted a signed-in user (e.g. Google/Email/Phone) even if
  // local session wasn't written yet, persist it and go straight to dashboard.
  final activeUser = authService.currentUser;
  if (savedSession == null && activeUser != null) {
    await sessionStorage.saveSession(
      uid: activeUser.uid,
      phone: activeUser.phoneNumber,
      displayName: activeUser.displayName,
      email: activeUser.email,
      role: 'shopkeeper',
    );
    initialLocation = AppRoutes.shopDashboard;
  }

  overrides.add(
    authServiceProvider.overrideWithValue(authService),
  );

  runApp(
    ProviderScope(
      overrides: overrides,
      child: EasyHisabApp(initialLocation: initialLocation),
    ),
  );
}
