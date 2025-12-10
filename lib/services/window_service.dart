import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size, Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

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
  bool _trayInitialized = false;

  /// 钉在桌面状态
  bool _isPinnedToDesktop = false;
  double _pinOpacity = 0.85; // 钉在桌面时的透明度

  /// 贴边隐藏状态
  bool _edgeHideEnabled = false;
  EdgeDirection _dockedEdge = EdgeDirection.none; // 窗口停靠的边缘
  bool _isHiddenAtEdge = false;
  Timer? _mouseCheckTimer;
  Offset _normalPosition = Offset.zero; // 正常位置（未隐藏时）
  Size _windowSize = const Size(1200, 800);
  Size _screenSize = const Size(1920, 1080);

  /// 应用程序根目录（用于托盘图标路径）
  String? _appDir;

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

  /// 钉在桌面时的透明度
  double get pinOpacity => _pinOpacity;

  /// 是否启用贴边隐藏
  bool get edgeHideEnabled => _edgeHideEnabled;

  /// 是否已隐藏在边缘
  bool get isHiddenAtEdge => _isHiddenAtEdge;

  /// 初始化窗口服务
  Future<void> initialize() async {
    if (!isWindows || _isInitialized) return;

    // 获取应用程序目录（用于托盘图标）
    _appDir = File(Platform.resolvedExecutable).parent.path;

    // 初始化窗口管理器
    await windowManager.ensureInitialized();

    // 获取屏幕尺寸
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    _screenSize = primaryDisplay.size;

    // 设置窗口选项 - 隐藏原生标题栏但保留窗口控制按钮
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(400, 300),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏原生标题栏
    );

    // 设置为可调整大小
    await windowManager.setResizable(true);

    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.show();
    await windowManager.focus();

    // 添加窗口监听器
    windowManager.addListener(this);

    _isInitialized = true;

    // 初始化系统托盘（延迟执行）
    Future.delayed(const Duration(milliseconds: 500), () {
      _initSystemTray();
    });
  }

  /// 初始化系统托盘
  /// 支持 .ico 或 .png 格式的图标文件
  Future<void> _initSystemTray() async {
    if (_trayInitialized) return;

    try {
      // 使用绝对路径查找图标文件
      String? iconPath;
      final basePath = _appDir ?? Directory.current.path;
      
      for (final relativePath in ['data/flutter_assets/assets/app_icon.ico', 'data/flutter_assets/assets/app_icon.png']) {
        final fullPath = '$basePath/$relativePath';
        if (await File(fullPath).exists()) {
          iconPath = fullPath;
          break;
        }
      }

      // 开发模式下尝试相对路径
      if (iconPath == null) {
        for (final path in ['assets/app_icon.ico', 'assets/app_icon.png']) {
          if (await File(path).exists()) {
            iconPath = path;
            break;
          }
        }
      }

      if (iconPath == null) {
        debugPrint('托盘图标文件不存在，托盘功能已禁用');
        debugPrint('请在 assets 目录下放置 app_icon.ico 或 app_icon.png 文件');
        return;
      }

      debugPrint('使用托盘图标: $iconPath');

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
        if (eventName == kSystemTrayEventClick) {
          restoreFromTray();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
        onTrayIconClick?.call();
      });

      _trayInitialized = true;
      debugPrint('托盘初始化成功');
    } catch (e) {
      debugPrint('托盘初始化失败: $e');
    }
  }

  /// 最小化到托盘（如果托盘未初始化则最小化到任务栏）
  Future<void> minimizeToTray() async {
    if (!isWindows) return;

    if (_trayInitialized) {
      await windowManager.hide();
      _isMinimizedToTray = true;
    } else {
      // 托盘未初始化，最小化到任务栏
      await windowManager.minimize();
    }
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

    _mouseCheckTimer?.cancel();
    if (_trayInitialized) {
      await _systemTray.destroy();
    }
    windowManager.removeListener(this);
  }

  /// 设置钉在桌面（半透明置顶）
  Future<void> setPinToDesktop(bool enabled, {double? opacity}) async {
    if (!isWindows) return;

    _isPinnedToDesktop = enabled;
    if (opacity != null) {
      _pinOpacity = opacity;
    }
    
    if (enabled) {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setOpacity(_pinOpacity);
      await windowManager.setSkipTaskbar(true);
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setOpacity(1.0);
      await windowManager.setSkipTaskbar(false);
    }
  }

  /// 设置钉在桌面的透明度
  Future<void> setPinOpacity(double opacity) async {
    if (!isWindows) return;
    
    _pinOpacity = opacity.clamp(0.3, 1.0);
    if (_isPinnedToDesktop) {
      await windowManager.setOpacity(_pinOpacity);
    }
  }

  /// 设置贴边隐藏
  /// 类似旧版 Windows QQ 的效果：
  /// 1. 窗口拖到屏幕边缘（左/右/上）时，记录为"贴边"状态
  /// 2. 鼠标离开窗口后，窗口自动隐藏到边缘，只露出几像素
  /// 3. 鼠标移到边缘时，窗口自动滑出
  Future<void> setEdgeHide(bool enabled) async {
    if (!isWindows) return;

    _edgeHideEnabled = enabled;
    if (enabled) {
      // 获取当前窗口位置和大小
      _normalPosition = await windowManager.getPosition();
      _windowSize = await windowManager.getSize();
      // 更新屏幕尺寸
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      _screenSize = primaryDisplay.size;
      // 检测当前是否已贴边
      _detectDockedEdge();
      // 启动鼠标位置检测
      _startMouseCheckTimer();
    } else {
      _mouseCheckTimer?.cancel();
      _mouseCheckTimer = null;
      // 如果当前隐藏，则恢复
      if (_isHiddenAtEdge) {
        await _showFromEdge();
      }
      _dockedEdge = EdgeDirection.none;
      _isHiddenAtEdge = false;
    }
  }

  /// 检测窗口是否贴边
  /// 只有窗口真正贴到屏幕边缘时才算贴边
  void _detectDockedEdge() {
    const threshold = 10.0; // 贴边判定阈值
    
    // 左边缘：窗口左边距离屏幕左边很近
    if (_normalPosition.dx <= threshold) {
      _dockedEdge = EdgeDirection.left;
      debugPrint('检测到贴边: 左');
    }
    // 右边缘：窗口右边距离屏幕右边很近
    else if (_normalPosition.dx + _windowSize.width >= _screenSize.width - threshold) {
      _dockedEdge = EdgeDirection.right;
      debugPrint('检测到贴边: 右');
    }
    // 上边缘：窗口上边距离屏幕上边很近
    else if (_normalPosition.dy <= threshold) {
      _dockedEdge = EdgeDirection.top;
      debugPrint('检测到贴边: 上');
    }
    // 不贴边
    else {
      _dockedEdge = EdgeDirection.none;
      debugPrint('未贴边，位置: $_normalPosition, 窗口大小: $_windowSize, 屏幕: $_screenSize');
    }
  }

  /// 启动鼠标位置检测定时器
  void _startMouseCheckTimer() {
    _mouseCheckTimer?.cancel();
    _mouseCheckTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _checkMousePosition(),
    );
  }

  /// 检测鼠标位置，决定是否显示/隐藏窗口
  Future<void> _checkMousePosition() async {
    if (!_edgeHideEnabled) return;
    // 如果没有贴边，不需要隐藏
    if (_dockedEdge == EdgeDirection.none && !_isHiddenAtEdge) return;

    try {
      final cursorPos = await screenRetriever.getCursorScreenPoint();

      if (_isHiddenAtEdge) {
        // 当前隐藏状态，检测鼠标是否靠近边缘触发显示
        bool shouldShow = false;
        const triggerZone = 5.0; // 触发显示的区域
        
        switch (_dockedEdge) {
          case EdgeDirection.left:
            // 鼠标在屏幕最左边，且 Y 坐标在窗口范围内
            shouldShow = cursorPos.dx <= triggerZone &&
                cursorPos.dy >= _normalPosition.dy &&
                cursorPos.dy <= _normalPosition.dy + _windowSize.height;
            break;
          case EdgeDirection.right:
            // 鼠标在屏幕最右边
            shouldShow = cursorPos.dx >= _screenSize.width - triggerZone &&
                cursorPos.dy >= _normalPosition.dy &&
                cursorPos.dy <= _normalPosition.dy + _windowSize.height;
            break;
          case EdgeDirection.top:
            // 鼠标在屏幕最上边
            shouldShow = cursorPos.dy <= triggerZone &&
                cursorPos.dx >= _normalPosition.dx &&
                cursorPos.dx <= _normalPosition.dx + _windowSize.width;
            break;
          case EdgeDirection.none:
            break;
        }

        if (shouldShow) {
          await _showFromEdge();
        }
      } else if (_dockedEdge != EdgeDirection.none) {
        // 当前显示状态且已贴边，检测鼠标是否离开窗口
        final windowPos = await windowManager.getPosition();
        final windowSize = await windowManager.getSize();
        
        // 窗口区域（加一点边距防止误触发）
        const margin = 10.0;
        final windowRect = Rect.fromLTWH(
          windowPos.dx - margin,
          windowPos.dy - margin,
          windowSize.width + margin * 2,
          windowSize.height + margin * 2,
        );

        final isMouseInWindow = windowRect.contains(cursorPos);

        // 鼠标离开窗口区域时隐藏
        if (!isMouseInWindow) {
          await _hideToEdge();
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 隐藏到边缘
  Future<void> _hideToEdge() async {
    if (_dockedEdge == EdgeDirection.none || _isHiddenAtEdge) return;

    _isHiddenAtEdge = true;
    const visiblePart = 3.0; // 露出的部分（像素）

    Offset hiddenPos;
    switch (_dockedEdge) {
      case EdgeDirection.left:
        // 向左隐藏，只露出右边 3 像素
        hiddenPos = Offset(-_windowSize.width + visiblePart, _normalPosition.dy);
        break;
      case EdgeDirection.right:
        // 向右隐藏，只露出左边 3 像素
        hiddenPos = Offset(_screenSize.width - visiblePart, _normalPosition.dy);
        break;
      case EdgeDirection.top:
        // 向上隐藏，只露出下边 3 像素
        hiddenPos = Offset(_normalPosition.dx, -_windowSize.height + visiblePart);
        break;
      case EdgeDirection.none:
        return;
    }

    await windowManager.setPosition(hiddenPos);
    debugPrint('隐藏到边缘: $hiddenPos');
  }

  /// 从边缘显示
  Future<void> _showFromEdge() async {
    if (!_isHiddenAtEdge) return;

    _isHiddenAtEdge = false;
    await windowManager.setPosition(_normalPosition);
    await windowManager.focus();
    debugPrint('从边缘显示: $_normalPosition');
  }

  // WindowListener 回调
  @override
  void onWindowClose() async {
    // 关闭时：如果托盘已初始化则最小化到托盘，否则直接退出
    if (_trayInitialized) {
      await minimizeToTray();
    } else {
      onExitApp?.call();
    }
  }

  @override
  void onWindowMinimize() {}

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
  void onWindowMoved() {
    // 窗口移动后更新位置记录
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      windowManager.getPosition().then((pos) {
        _normalPosition = pos;
        _detectDockedEdge();
      });
    }
  }

  @override
  void onWindowResized() {
    // 窗口大小改变后更新记录
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      windowManager.getSize().then((size) {
        _windowSize = size;
        _detectDockedEdge();
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
