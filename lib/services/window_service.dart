import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size, Offset;

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

/// 贴边方向
enum EdgeDirection {
  none,
  left,
  right,
  top,
}

/// 窗口服务 - 管理 Windows 平台的窗口和系统托盘
class WindowService with WindowListener {
  static WindowService? _instance;
  static WindowService get instance => _instance ??= WindowService._();

  WindowService._();

  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
  bool _isMinimizedToTray = false;

  /// 钉在桌面状态
  bool _isPinnedToDesktop = false;

  /// 贴边隐藏状态
  bool _edgeHideEnabled = false;
  EdgeDirection _currentEdge = EdgeDirection.none;
  bool _isHiddenAtEdge = false;
  Timer? _edgeCheckTimer;
  Offset? _lastWindowPosition;
  Size? _lastWindowSize;

  /// 回调函数
  void Function()? onTrayIconClick;
  void Function()? onShowWindow;
  void Function()? onExitApp;

  /// 是否是 Windows 平台
  bool get isWindows => !kIsWeb && Platform.isWindows;

  /// 是否已最小化到托盘
  bool get isMinimizedToTray => _isMinimizedToTray;

  /// 是否钉在桌面
  bool get isPinnedToDesktop => _isPinnedToDesktop;

  /// 是否启用贴边隐藏
  bool get edgeHideEnabled => _edgeHideEnabled;

  /// 是否已隐藏在边缘
  bool get isHiddenAtEdge => _isHiddenAtEdge;

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
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.show();
    await windowManager.focus();

    // 添加窗口监听器
    windowManager.addListener(this);

    // 初始化系统托盘（延迟执行，避免阻塞）
    Future.delayed(const Duration(milliseconds: 500), () {
      _initSystemTray();
    });

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

    _edgeCheckTimer?.cancel();
    await _systemTray.destroy();
    windowManager.removeListener(this);
  }

  /// 设置钉在桌面（半透明置顶）
  Future<void> setPinToDesktop(bool enabled) async {
    if (!isWindows) return;

    _isPinnedToDesktop = enabled;
    if (enabled) {
      // 设置窗口始终置顶，半透明，不占用任务栏位置
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setOpacity(0.85); // 85% 不透明度
      await windowManager.setSkipTaskbar(true);
    } else {
      // 恢复正常窗口
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setOpacity(1.0); // 完全不透明
      await windowManager.setSkipTaskbar(false);
    }
  }

  /// 设置贴边隐藏
  Future<void> setEdgeHide(bool enabled) async {
    if (!isWindows) return;

    _edgeHideEnabled = enabled;
    if (enabled) {
      // 启动边缘检测定时器
      _startEdgeCheckTimer();
    } else {
      // 停止边缘检测
      _edgeCheckTimer?.cancel();
      _edgeCheckTimer = null;
      // 如果当前隐藏在边缘，恢复窗口
      if (_isHiddenAtEdge) {
        await _showFromEdge();
      }
    }
  }

  /// 启动边缘检测定时器
  void _startEdgeCheckTimer() {
    _edgeCheckTimer?.cancel();
    _edgeCheckTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _checkEdgeAndMouse(),
    );
  }

  /// 检测窗口边缘和鼠标位置
  Future<void> _checkEdgeAndMouse() async {
    if (!_edgeHideEnabled) return;

    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();

    // 检测窗口是否贴边
    final screenWidth = 1920.0; // TODO: 获取实际屏幕尺寸
    const edgeThreshold = 10.0;

    EdgeDirection newEdge = EdgeDirection.none;
    if (position.dx <= edgeThreshold) {
      newEdge = EdgeDirection.left;
    } else if (position.dx + size.width >= screenWidth - edgeThreshold) {
      newEdge = EdgeDirection.right;
    } else if (position.dy <= edgeThreshold) {
      newEdge = EdgeDirection.top;
    }

    if (newEdge != EdgeDirection.none && !_isHiddenAtEdge) {
      _currentEdge = newEdge;
      _lastWindowPosition = position;
      _lastWindowSize = size;
    }

    // 如果窗口失去焦点且贴边，则隐藏
    final isFocused = await windowManager.isFocused();
    if (!isFocused && _currentEdge != EdgeDirection.none && !_isHiddenAtEdge) {
      await _hideToEdge();
    }
  }

  /// 隐藏到边缘
  Future<void> _hideToEdge() async {
    if (_currentEdge == EdgeDirection.none || _lastWindowSize == null) return;

    _isHiddenAtEdge = true;
    final size = _lastWindowSize!;
    const visiblePart = 5.0; // 露出的部分

    switch (_currentEdge) {
      case EdgeDirection.left:
        await windowManager.setPosition(Offset(-size.width + visiblePart, _lastWindowPosition!.dy));
        break;
      case EdgeDirection.right:
        final screenWidth = 1920.0; // TODO: 获取实际屏幕尺寸
        await windowManager.setPosition(Offset(screenWidth - visiblePart, _lastWindowPosition!.dy));
        break;
      case EdgeDirection.top:
        await windowManager.setPosition(Offset(_lastWindowPosition!.dx, -size.height + visiblePart));
        break;
      case EdgeDirection.none:
        break;
    }
  }

  /// 从边缘显示
  Future<void> _showFromEdge() async {
    if (!_isHiddenAtEdge || _lastWindowPosition == null) return;

    _isHiddenAtEdge = false;
    await windowManager.setPosition(_lastWindowPosition!);
    await windowManager.focus();
  }

  /// 鼠标进入边缘区域时调用（需要从外部触发）
  Future<void> onMouseEnterEdge() async {
    if (_edgeHideEnabled && _isHiddenAtEdge) {
      await _showFromEdge();
    }
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
  void onWindowFocus() {
    // 窗口获得焦点时，如果隐藏在边缘则显示
    if (_isHiddenAtEdge) {
      _showFromEdge();
    }
  }

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
  void onWindowMoved() {
    // 窗口移动后更新位置记录
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      windowManager.getPosition().then((pos) {
        _lastWindowPosition = pos;
      });
    }
  }

  @override
  void onWindowResized() {
    // 窗口大小改变后更新记录
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      windowManager.getSize().then((size) {
        _lastWindowSize = size;
      });
    }
  }

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}
}


