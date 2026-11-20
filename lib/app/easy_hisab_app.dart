import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_router.dart';

class EasyHisabApp extends ConsumerStatefulWidget {
  const EasyHisabApp({super.key, this.initialLocation = AppRoutes.chooseRole});

  final String initialLocation;

  @override
  ConsumerState<EasyHisabApp> createState() => _EasyHisabAppState();
}

class _EasyHisabAppState extends ConsumerState<EasyHisabApp> {
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
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (themeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyleFor(effectiveBrightness),
      child: MaterialApp.router(
        title: 'EasyHisab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: _router,
      ),
    );
  }
}
