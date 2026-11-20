import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'easyhisab_theme_mode';

/// Preloaded initial theme mode (loaded during app startup / splash).
/// Defaults to [ThemeMode.dark] on first launch.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

/// Loads the persisted [ThemeMode] from [SharedPreferences].
/// Defaults to [ThemeMode.dark] if not yet saved.
Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  } catch (_) {
    return ThemeMode.dark;
  }
}

/// Manages the active [ThemeMode] and persists changes to [SharedPreferences].
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.watch(initialThemeModeProvider);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_kThemeModeKey, value);
    } catch (_) {
      // Safe fallback in test environments without platform SharedPreferences.
    }
  }

  Future<void> toggle(Brightness currentBrightness) async {
    final next =
        currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
