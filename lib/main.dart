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
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialThemeMode = await loadSavedThemeMode();
  runApp(EasyHisabBootstrap(initialThemeMode: initialThemeMode));
}

class EasyHisabBootstrap extends StatefulWidget {
  const EasyHisabBootstrap({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  State<EasyHisabBootstrap> createState() => _EasyHisabBootstrapState();
}

class _EasyHisabBootstrapState extends State<EasyHisabBootstrap> {
  String? _resolvedRoute;
  List<dynamic> _overrides = const [];

  Future<String> _initializeApp() async {
    final database = await LocalDatabase.open();
    final sessionStorage = LocalSessionStorage(database);
    final savedSession = await sessionStorage.loadSession();

    String initialLocation = AppRoutes.chooseRole;
    if (savedSession != null) {
      initialLocation = savedSession.role == 'customer'
          ? AppRoutes.customerShops
          : AppRoutes.shopDashboard;
    }

    final overrides = <dynamic>[
      initialThemeModeProvider.overrideWithValue(widget.initialThemeMode),
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

    overrides.add(authServiceProvider.overrideWithValue(authService));
    _overrides = overrides;
    return initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: _resolvedRoute == null
          ? MaterialApp(
              key: const ValueKey('splash_app'),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: widget.initialThemeMode,
              home: SplashScreen(
                onInitialize: _initializeApp,
                onReady: (route) {
                  setState(() => _resolvedRoute = route);
                },
              ),
            )
          : ProviderScope(
              key: const ValueKey('main_app'),
              overrides: _overrides.cast(),
              child: EasyHisabApp(initialLocation: _resolvedRoute!),
            ),
    );
  }
}
