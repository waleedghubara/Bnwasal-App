import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cache/cache_helper.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  final SecureCacheHelper _cacheHelper;
  static const String _themeModeKey = 'theme_mode';

  ThemeCubit(this._cacheHelper) : super(const ThemeState()) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final cachedTheme = await _cacheHelper.getData(key: _themeModeKey);
      if (cachedTheme != null) {
        final mode = ThemeMode.values.firstWhere(
          (e) => e.name == cachedTheme,
          orElse: () => ThemeMode.system,
        );
        emit(ThemeState(themeMode: mode));
      }
    } catch (_) {
      // Fallback to system default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(ThemeState(themeMode: mode));
    await _cacheHelper.saveData(key: _themeModeKey, value: mode.name);
  }

  Future<void> toggleTheme() async {
    final currentMode = state.themeMode;
    ThemeMode nextMode;
    if (currentMode == ThemeMode.dark) {
      nextMode = ThemeMode.light;
    } else {
      nextMode = ThemeMode.dark;
    }
    await setThemeMode(nextMode);
  }
}
