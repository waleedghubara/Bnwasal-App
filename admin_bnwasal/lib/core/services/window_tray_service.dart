import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowTrayService with WindowListener, TrayListener {
  static final WindowTrayService _instance = WindowTrayService._();
  factory WindowTrayService() => _instance;
  WindowTrayService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isWindows) return;

    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      await windowManager.setMinimumSize(const Size(800, 600));
      
      // جعل النافذة تبدأ كـ Maximized (حجم كامل الشاشة) عند بدء التشغيل
      await windowManager.maximize();

      windowManager.addListener(this);

      await trayManager.setIcon('assets/images/icon.ico');

      final Menu menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Open App'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Close App'),
        ],
      );
      await trayManager.setContextMenu(menu);
      trayManager.addListener(this);

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing WindowTrayService: $e');
    }
  }

  // WindowListener methods
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  // TrayListener methods
  @override
  void onTrayIconMouseDown() async {
    await _showApp();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await _showApp();
    } else if (menuItem.key == 'exit_app') {
      await _exitApp();
    }
  }

  Future<void> _showApp() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('Error showing app window: $e');
    }
  }

  Future<void> _exitApp() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      exit(0);
    } catch (e) {
      debugPrint('Error exiting app: $e');
      exit(0);
    }
  }
}
