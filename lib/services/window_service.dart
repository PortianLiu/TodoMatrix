import 'dart:io';
import 'dart:ui' show Size, Color;

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口事件类型
enum WindowEventType {
  minimized,
  restored,
  closed,
  focused,
  blurred,
}

/// 窗口事件
class WindowEvent {
  final WindowEventType type;
  final DateTime timestamp;

  WindowEvent(this.type) : timestamp = DateTime.now();
}

/// 窗口服务 - 管理 Windows 平台的窗口和系统托盘
class WindowService with WindowListener {
  static WindowService? _instance;
  static WindowService get instance => _instance ??= WindowService._();

  WindowService._();

  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
  bool _isMinimizedToTray = false;

  /// 回调函数
  void Function()? onTrayIconClick;
  void Function()? onShowWindow;
  void Function()? onExitApp;

  /// 是否是 Windows 平台
  bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 是否已最小化到托盘
  bool get isMinimizedToTray => _isMinimizedToTray;

  /// 初始化窗口服务
  Future<void> initialize() async {
    if (!isWindows || _isInitialized) return;

    // 初始化窗口管理器
    await windowManager.ensureInitialized();

    // 设置窗口选项
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(400, 300),
      center: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 添加窗口监听器
    windowManager.addListener(this);

    // 初始化系统托盘
    await _initSystemTray();

    _isInitialized = true;
  }

  /// 初始化系统托盘
  Future<void> _initSystemTray() async {
    // 设置托盘图标
    // Windows 使用 .ico 文件，其他平台使用 .png
    // 如果没有自定义图标，使用空字符串让系统使用默认图标
    String iconPath = '';

    await _systemTray.initSystemTray(
      title: 'TodoMatrix',
      iconPath: iconPath,
      toolTip: 'TodoMatrix - 待办事项管理',
    );

    // 设置托盘菜单
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '显示窗口',
        onClicked: (menuItem) => restoreFromTray(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (menuItem) => _handleExit(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    // 注册托盘图标点击事件
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick ||
          eventName == kSystemTrayEventRightClick) {
        // 左键点击恢复窗口，右键显示菜单
        if (eventName == kSystemTrayEventClick) {
          restoreFromTray();
        } else {
          _systemTray.popUpContextMenu();
        }
        onTrayIconClick?.call();
      }
    });
  }

  /// 最小化到托盘
  Future<void> minimizeToTray() async {
    if (!isWindows) return;

    await windowManager.hide();
    _isMinimizedToTray = true;
  }

  /// 从托盘恢复窗口
  Future<void> restoreFromTray() async {
    if (!isWindows) return;

    await windowManager.show();
    await windowManager.focus();
    _isMinimizedToTray = false;
    onShowWindow?.call();
  }

  /// 处理退出
  void _handleExit() {
    onExitApp?.call();
  }

  /// 销毁托盘
  Future<void> destroy() async {
    if (!isWindows) return;

    await _systemTray.destroy();
    windowManager.removeListener(this);
  }

  // WindowListener 回调
  @override
  void onWindowClose() async {
    // 关闭时最小化到托盘而不是退出
    await minimizeToTray();
  }

  @override
  void onWindowMinimize() {
    // 可以选择最小化时也隐藏到托盘
  }

  @override
  void onWindowRestore() {
    _isMinimizedToTray = false;
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}
}


