import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size, Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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
  bool _isDragging = false; // 是否正在拖拽窗口
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
  /// Windows 平台需要 .ico 格式图标，会自动从 PNG 转换
  Future<void> _initSystemTray() async {
    if (_trayInitialized) return;

    try {
      // 获取或创建 ICO 图标
      final iconPath = await _getOrCreateIcoIcon();
      
      if (iconPath == null) {
        debugPrint('托盘图标文件不存在，托盘功能已禁用');
        debugPrint('请在 assets 目录下放置 app_icon.png 或 app_icon.ico 文件');
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

  /// 获取或创建 ICO 图标
  /// 如果已有 ICO 文件则直接使用，否则从 PNG 转换
  Future<String?> _getOrCreateIcoIcon() async {
    final basePath = _appDir ?? Directory.current.path;
    
    // 1. 首先检查是否已有 ICO 文件
    final releaseIcoPath = '$basePath/data/flutter_assets/assets/app_icon.ico';
    final devIcoPath = 'assets/app_icon.ico';
    
    if (await File(releaseIcoPath).exists()) {
      return releaseIcoPath;
    }
    if (await File(devIcoPath).exists()) {
      return devIcoPath;
    }
    
    // 2. 检查是否有 PNG 文件，如果有则转换为 ICO
    final releasePngPath = '$basePath/data/flutter_assets/assets/app_icon.png';
    final devPngPath = 'assets/app_icon.png';
    
    String? pngPath;
    if (await File(releasePngPath).exists()) {
      pngPath = releasePngPath;
    } else if (await File(devPngPath).exists()) {
      pngPath = devPngPath;
    }
    
    if (pngPath != null) {
      // 从 PNG 转换为 ICO
      return await _convertPngToIco(pngPath);
    }
    
    // 3. 尝试从 Flutter assets 加载
    try {
      final byteData = await rootBundle.load('assets/app_icon.png');
      final bytes = byteData.buffer.asUint8List();
      return await _convertPngBytesToIco(bytes);
    } catch (e) {
      debugPrint('无法从 assets 加载图标: $e');
    }
    
    return null;
  }

  /// 将 PNG 文件转换为 ICO 格式
  Future<String?> _convertPngToIco(String pngPath) async {
    try {
      final pngFile = File(pngPath);
      final bytes = await pngFile.readAsBytes();
      return await _convertPngBytesToIco(bytes);
    } catch (e) {
      debugPrint('PNG 转 ICO 失败: $e');
      return null;
    }
  }

  /// 将 PNG 字节数据转换为 ICO 格式
  Future<String?> _convertPngBytesToIco(Uint8List pngBytes) async {
    try {
      // 解码 PNG
      final image = img.decodeImage(pngBytes);
      if (image == null) {
        debugPrint('无法解码 PNG 图像');
        return null;
      }
      
      // 调整大小为 32x32（托盘图标标准尺寸）
      final resized = img.copyResize(image, width: 32, height: 32);
      
      // 编码为 ICO
      final icoBytes = img.encodeIco(resized);
      
      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final icoPath = '${tempDir.path}/app_icon.ico';
      final icoFile = File(icoPath);
      await icoFile.writeAsBytes(icoBytes);
      
      debugPrint('PNG 已转换为 ICO: $icoPath');
      return icoPath;
    } catch (e) {
      debugPrint('PNG 转 ICO 失败: $e');
      return null;
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
  /// 1. 拖拽窗口时，当鼠标到达屏幕边缘（左/右/上）时，记录为"贴边"状态
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
      // 重置贴边状态
      _dockedEdge = EdgeDirection.none;
      _isHiddenAtEdge = false;
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
      _isDragging = false;
    }
  }

  /// 在拖拽结束时检测鼠标是否在屏幕边缘
  /// 这是贴边的核心判定逻辑
  Future<void> _checkEdgeOnDragEnd() async {
    if (!_edgeHideEnabled) return;

    try {
      final cursorPos = await screenRetriever.getCursorScreenPoint();
      final windowPos = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();
      
      // 更新窗口信息
      _normalPosition = windowPos;
      _windowSize = windowSize;
      
      // 更新屏幕尺寸
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      _screenSize = primaryDisplay.size;
      
      const edgeThreshold = 5.0; // 鼠标距离屏幕边缘的阈值
      
      // 检测鼠标是否在屏幕边缘
      if (cursorPos.dx <= edgeThreshold) {
        // 鼠标在左边缘
        _dockedEdge = EdgeDirection.left;
        // 将窗口贴到左边缘
        _normalPosition = Offset(0, windowPos.dy);
        await windowManager.setPosition(_normalPosition);
        debugPrint('贴边: 左（鼠标位置: $cursorPos）');
      } else if (cursorPos.dx >= _screenSize.width - edgeThreshold) {
        // 鼠标在右边缘
        _dockedEdge = EdgeDirection.right;
        // 将窗口贴到右边缘
        _normalPosition = Offset(_screenSize.width - windowSize.width, windowPos.dy);
        await windowManager.setPosition(_normalPosition);
        debugPrint('贴边: 右（鼠标位置: $cursorPos）');
      } else if (cursorPos.dy <= edgeThreshold) {
        // 鼠标在上边缘
        _dockedEdge = EdgeDirection.top;
        // 将窗口贴到上边缘
        _normalPosition = Offset(windowPos.dx, 0);
        await windowManager.setPosition(_normalPosition);
        debugPrint('贴边: 上（鼠标位置: $cursorPos）');
      } else {
        // 不在边缘，取消贴边状态
        _dockedEdge = EdgeDirection.none;
        debugPrint('未贴边（鼠标位置: $cursorPos）');
      }
    } catch (e) {
      debugPrint('检测贴边失败: $e');
    }
  }

  /// 启动鼠标位置检测定时器
  void _startMouseCheckTimer() {
    _mouseCheckTimer?.cancel();
    _mouseCheckTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _checkMousePosition(),
    );
  }

  /// 检测鼠标位置，决定是否显示/隐藏窗口
  Future<void> _checkMousePosition() async {
    if (!_edgeHideEnabled) return;

    try {
      final cursorPos = await screenRetriever.getCursorScreenPoint();

      if (_isHiddenAtEdge) {
        // 当前隐藏状态，检测鼠标是否靠近边缘触发显示
        bool shouldShow = false;
        const triggerZone = 3.0; // 触发显示的区域（像素）
        
        switch (_dockedEdge) {
          case EdgeDirection.left:
            // 鼠标在屏幕最左边
            shouldShow = cursorPos.dx <= triggerZone;
            break;
          case EdgeDirection.right:
            // 鼠标在屏幕最右边
            shouldShow = cursorPos.dx >= _screenSize.width - triggerZone;
            break;
          case EdgeDirection.top:
            // 鼠标在屏幕最上边
            shouldShow = cursorPos.dy <= triggerZone;
            break;
          case EdgeDirection.none:
            break;
        }

        if (shouldShow) {
          await _showFromEdge();
        }
      } else if (_dockedEdge != EdgeDirection.none && !_isDragging) {
        // 当前显示状态且已贴边且不在拖拽，检测鼠标是否离开窗口
        final windowPos = await windowManager.getPosition();
        final windowSize = await windowManager.getSize();
        
        // 窗口区域（加一点边距防止误触发）
        const margin = 15.0;
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

  /// 通知开始拖拽窗口
  void notifyDragStart() {
    _isDragging = true;
  }

  /// 通知结束拖拽窗口
  Future<void> notifyDragEnd() async {
    _isDragging = false;
    // 拖拽结束时检测是否贴边
    await _checkEdgeOnDragEnd();
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
    // 窗口移动完成后检测贴边（拖拽结束）
    if (_edgeHideEnabled && !_isHiddenAtEdge && _isDragging) {
      // 延迟一点执行，确保拖拽真正结束
      Future.delayed(const Duration(milliseconds: 50), () {
        notifyDragEnd();
      });
    }
  }

  @override
  void onWindowResized() {
    // 窗口大小改变后更新记录
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      windowManager.getSize().then((size) {
        _windowSize = size;
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
