import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'app_theme.dart';

class EasyHisabApp extends StatefulWidget {
  const EasyHisabApp({super.key, this.initialLocation = AppRoutes.chooseRole});

  final String initialLocation;

  @override
  State<EasyHisabApp> createState() => _EasyHisabAppState();
}

class _EasyHisabAppState extends State<EasyHisabApp> {
  late final GoRouter _router = createRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasyHisab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
