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
  bool _isClickThrough = false; // 鼠标穿透状态

  /// 贴边隐藏状态
  bool _edgeHideEnabled = false;
  EdgeDirection _dockedEdge = EdgeDirection.none; // 窗口停靠的边缘
  bool _isHiddenAtEdge = false;
  bool _isDragging = false; // 是否正在拖拽窗口
  Timer? _mouseCheckTimer;
  Timer? _dragEndDebounceTimer; // 拖拽结束防抖定时器
  Offset _normalPosition = Offset.zero; // 正常位置（未隐藏时）
  Size _windowSize = const Size(1200, 800);
  
  /// 当前窗口所在显示器的工作区域
  /// 多屏支持：根据窗口中心点所在的显示器动态更新
  /// 支持任意显示器布局（左、右、上、下、不规则）
  Rect _currentDisplayBounds = Rect.zero;

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

  /// 是否鼠标穿透
  bool get isClickThrough => _isClickThrough;

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
      await _updateTrayMenu();

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

  /// 更新托盘菜单
  Future<void> _updateTrayMenu() async {
    final menu = Menu();
    final menuItems = <MenuItemBase>[
      MenuItemLabel(
        label: '显示窗口',
        onClicked: (menuItem) => restoreFromTray(),
      ),
      // 鼠标穿透选项（始终显示，但只有钉住时才能生效）
      MenuItemLabel(
        label: _isClickThrough ? '鼠标穿透 ✓' : '鼠标穿透',
        onClicked: (menuItem) => toggleClickThrough(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (menuItem) => _handleExit(),
      ),
    ];

    await menu.buildFrom(menuItems);
    await _systemTray.setContextMenu(menu);
  }

  /// 销毁托盘
  Future<void> destroy() async {
    if (!isWindows) return;

    _mouseCheckTimer?.cancel();
    _dragEndDebounceTimer?.cancel();
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
      // 如果穿透状态为开启，恢复穿透
      if (_isClickThrough) {
        await windowManager.setIgnoreMouseEvents(true);
      }
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setOpacity(1.0);
      await windowManager.setSkipTaskbar(false);
      // 取消钉住时，关闭鼠标穿透效果（但保留状态，下次钉住时恢复）
      await windowManager.setIgnoreMouseEvents(false);
    }
    // 更新托盘菜单（如果已初始化）
    if (_trayInitialized) {
      await _updateTrayMenu();
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

  /// 设置鼠标穿透（仅在钉住时生效）
  Future<void> setClickThrough(bool enabled) async {
    if (!isWindows) return;
    
    // 只有钉住时才能开启穿透
    if (enabled && !_isPinnedToDesktop) {
      debugPrint('鼠标穿透仅在钉住桌面时生效');
      return;
    }
    
    _isClickThrough = enabled;
    // 只设置鼠标穿透，不影响透明度
    await windowManager.setIgnoreMouseEvents(enabled);
    // 更新托盘菜单（如果已初始化）
    if (_trayInitialized) {
      await _updateTrayMenu();
    }
  }

  /// 切换鼠标穿透状态
  Future<void> toggleClickThrough() async {
    await setClickThrough(!_isClickThrough);
  }

  /// 设置贴边隐藏
  /// 类似旧版 Windows QQ 的效果：
  /// 1. 鼠标离开窗口时，检查窗口是否处于屏幕边缘
  /// 2. 如果窗口贴边，则自动隐藏到边缘，只露出几像素
  /// 3. 鼠标移到边缘时，窗口自动滑出
  Future<void> setEdgeHide(bool enabled) async {
    if (!isWindows) return;

    _edgeHideEnabled = enabled;
    if (enabled) {
      // 获取当前窗口位置和大小
      _normalPosition = await windowManager.getPosition();
      _windowSize = await windowManager.getSize();
      // 更新当前显示器边界（忽略返回值，初始化时不需要检查跨屏）
      await _updateCurrentDisplayBounds(_normalPosition);
      // 重置状态
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

  /// 更新当前窗口所在显示器的边界
  /// 返回 true 表示窗口只在一个显示器上，false 表示窗口同时处于多个显示器
  Future<bool> _updateCurrentDisplayBounds(Offset windowPos) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      // 稍微缩小窗口矩形，避免边缘接触被误判为重叠
      const shrink = 5.0;
      final windowRect = Rect.fromLTWH(
        windowPos.dx + shrink,
        windowPos.dy + shrink,
        _windowSize.width - shrink * 2,
        _windowSize.height - shrink * 2,
      );
      
      // 找到窗口中心点所在的显示器
      final windowCenter = Offset(
        windowPos.dx + _windowSize.width / 2,
        windowPos.dy + _windowSize.height / 2,
      );
      
      Rect? foundBounds;
      int overlappingDisplays = 0; // 窗口覆盖的显示器数量
      
      for (final display in displays) {
        final bounds = Rect.fromLTWH(
          display.visiblePosition?.dx ?? 0,
          display.visiblePosition?.dy ?? 0,
          display.visibleSize?.width ?? display.size.width,
          display.visibleSize?.height ?? display.size.height,
        );
        
        // 检查窗口是否与此显示器有实质性重叠（不只是边缘接触）
        final intersection = windowRect.intersect(bounds);
        if (intersection.width > 0 && intersection.height > 0) {
          overlappingDisplays++;
        }
        
        if (bounds.contains(windowCenter)) {
          foundBounds = bounds;
        }
      }
      
      if (foundBounds == null) {
        // 如果没找到，使用主显示器
        final primary = await screenRetriever.getPrimaryDisplay();
        foundBounds = Rect.fromLTWH(
          0, 0,
          primary.visibleSize?.width ?? primary.size.width,
          primary.visibleSize?.height ?? primary.size.height,
        );
      }
      
      _currentDisplayBounds = foundBounds;
      
      // 窗口只在一个显示器上时返回 true
      // 窗口同时处于多个显示器时返回 false（跨屏）
      final isOnSingleDisplay = overlappingDisplays <= 1;
      
      debugPrint('当前显示器边界: $_currentDisplayBounds, 覆盖显示器数: $overlappingDisplays');
      return isOnSingleDisplay;
    } catch (e) {
      debugPrint('获取显示器信息失败: $e');
      return true; // 出错时默认允许贴边
    }
  }

  /// 检测窗口是否处于屏幕边缘（基于当前显示器）
  /// 返回贴边方向
  /// 优先级：上 > 左 > 右
  EdgeDirection _detectWindowEdge(Offset windowPos, Size windowSize) {
    const threshold = 10.0; // 窗口距离屏幕边缘的阈值
    
    final displayLeft = _currentDisplayBounds.left;
    final displayRight = _currentDisplayBounds.right;
    final displayTop = _currentDisplayBounds.top;
    
    // 上边缘优先：窗口上边贴着显示器上边
    if (windowPos.dy <= displayTop + threshold) {
      return EdgeDirection.top;
    }
    // 左边缘次之：窗口左边贴着显示器左边
    if (windowPos.dx <= displayLeft + threshold) {
      return EdgeDirection.left;
    }
    // 右边缘最后：窗口右边贴着显示器右边
    if (windowPos.dx + windowSize.width >= displayRight - threshold) {
      return EdgeDirection.right;
    }
    
    return EdgeDirection.none;
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
    if (!_edgeHideEnabled || _isDragging) return;

    try {
      final cursorPos = await screenRetriever.getCursorScreenPoint();
      final windowPos = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();

      if (_isHiddenAtEdge) {
        // 当前隐藏状态，检测鼠标是否靠近边缘触发显示
        bool shouldShow = false;
        const triggerZone = 3.0; // 触发显示的区域（像素）
        
        switch (_dockedEdge) {
          case EdgeDirection.left:
            shouldShow = cursorPos.dx <= _currentDisplayBounds.left + triggerZone;
            break;
          case EdgeDirection.right:
            shouldShow = cursorPos.dx >= _currentDisplayBounds.right - triggerZone;
            break;
          case EdgeDirection.top:
            shouldShow = cursorPos.dy <= _currentDisplayBounds.top + triggerZone;
            break;
          case EdgeDirection.none:
            break;
        }

        if (shouldShow) {
          await _showFromEdge();
        }
      } else {
        // 当前显示状态，检测鼠标是否离开窗口
        const margin = 15.0;
        final windowRect = Rect.fromLTWH(
          windowPos.dx - margin,
          windowPos.dy - margin,
          windowSize.width + margin * 2,
          windowSize.height + margin * 2,
        );

        final isMouseInWindow = windowRect.contains(cursorPos);

        // 鼠标离开窗口区域时，检查窗口是否贴边
        if (!isMouseInWindow) {
          // 更新当前显示器边界（窗口可能被拖到其他显示器）
          // 如果窗口跨越多个显示器，不进行贴边操作（避免不同缩放比导致的计算错误）
          final isFullyInDisplay = await _updateCurrentDisplayBounds(windowPos);
          if (!isFullyInDisplay) {
            debugPrint('窗口跨越多个显示器，跳过贴边检测');
            return;
          }
          
          // 检测窗口是否处于屏幕边缘
          final edge = _detectWindowEdge(windowPos, windowSize);
          if (edge != EdgeDirection.none) {
            // 窗口贴边，记录位置并隐藏
            _dockedEdge = edge;
            _normalPosition = windowPos;
            _windowSize = windowSize;
            await _hideToEdge();
          }
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
        hiddenPos = Offset(
          _currentDisplayBounds.left - _windowSize.width + visiblePart,
          _normalPosition.dy,
        );
        break;
      case EdgeDirection.right:
        // 向右隐藏，只露出左边 3 像素
        hiddenPos = Offset(
          _currentDisplayBounds.right - visiblePart,
          _normalPosition.dy,
        );
        break;
      case EdgeDirection.top:
        // 向上隐藏，只露出下边 3 像素
        hiddenPos = Offset(
          _normalPosition.dx,
          _currentDisplayBounds.top - _windowSize.height + visiblePart,
        );
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
    debugPrint('拖拽开始');
    _isDragging = true;
    // 拖拽时禁用最大化，防止触发 Windows Snap
    if (_edgeHideEnabled) {
      windowManager.setMaximizable(false);
    }
  }

  /// 通知结束拖拽窗口
  /// 注意：由于 windowManager.startDragging() 会接管鼠标事件，
  /// Flutter 的 onPanEnd 可能不会触发，所以主要依赖 onWindowMoved 的防抖检测
  Future<void> notifyDragEnd() async {
    debugPrint('notifyDragEnd 被调用, _isDragging=$_isDragging');
    // 取消防抖定时器，立即处理
    _dragEndDebounceTimer?.cancel();
    
    if (!_isDragging) return; // 已经处理过了
    _isDragging = false;
    
    // 恢复最大化功能
    if (_edgeHideEnabled) {
      await windowManager.setMaximizable(true);
      // 贴边回弹：如果窗口靠近边缘，自动吸附到边缘
      await _snapToEdgeIfNeeded();
    }
  }

  /// 贴边回弹：如果窗口靠近边缘，自动吸附到边缘
  /// 下界回弹：如果窗口下边超出屏幕，只需保证标题栏露出即可
  Future<void> _snapToEdgeIfNeeded() async {
    if (!_edgeHideEnabled) return;

    try {
      final windowPos = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();
      _windowSize = windowSize;
      
      // 更新当前显示器边界
      // 如果窗口跨越多个显示器，不进行贴边回弹（避免不同缩放比导致的计算错误）
      final isOnSingleDisplay = await _updateCurrentDisplayBounds(windowPos);
      if (!isOnSingleDisplay) {
        debugPrint('窗口跨越多个显示器，跳过贴边回弹');
        return;
      }
      
      // 检测是否靠近边缘（上、左、右）
      final edge = _detectWindowEdge(windowPos, windowSize);
      
      // 计算吸附位置
      double newX = windowPos.dx;
      double newY = windowPos.dy;
      bool needSnap = false;
      
      // 处理上、左、右边缘吸附
      switch (edge) {
        case EdgeDirection.left:
          newX = _currentDisplayBounds.left;
          needSnap = true;
          break;
        case EdgeDirection.right:
          newX = _currentDisplayBounds.right - windowSize.width;
          needSnap = true;
          break;
        case EdgeDirection.top:
          newY = _currentDisplayBounds.top;
          needSnap = true;
          break;
        case EdgeDirection.none:
          break;
      }
      
      // 下界回弹：如果窗口下边超出屏幕，保证标题栏露出
      // visibleSize 已经排除了任务栏，所以 bottom 就是任务栏上方
      const minVisibleHeight = 60.0; // 至少露出的高度（标题栏 + 一点内容）
      final displayBottom = _currentDisplayBounds.bottom;
      final windowBottom = windowPos.dy + windowSize.height;
      final visibleHeight = displayBottom - windowPos.dy; // 窗口在屏幕内的高度
      
      if (visibleHeight < minVisibleHeight) {
        // 窗口露出部分不足，需要回弹
        newY = displayBottom - minVisibleHeight;
        needSnap = true;
        debugPrint('下界回弹: 露出高度 $visibleHeight < $minVisibleHeight');
      }
      
      if (needSnap) {
        final snappedPos = Offset(newX, newY);
        await windowManager.setPosition(snappedPos);
        debugPrint('贴边回弹: $snappedPos (边缘: $edge)');
      }
    } catch (e) {
      debugPrint('贴边回弹失败: $e');
    }
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
    // 使用防抖检测拖拽结束：每次移动都重置定时器，停止移动 200ms 后认为拖拽结束
    if (_edgeHideEnabled && !_isHiddenAtEdge) {
      // 如果还没标记为拖拽状态，先标记
      if (!_isDragging) {
        _isDragging = true;
        windowManager.setMaximizable(false);
        debugPrint('检测到窗口移动，标记为拖拽状态');
      }
      
      _dragEndDebounceTimer?.cancel();
      _dragEndDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        _onDragEndDetected();
      });
    }
  }

  /// 检测到拖拽结束（通过防抖）
  Future<void> _onDragEndDetected() async {
    debugPrint('防抖检测：拖拽结束, _isDragging=$_isDragging');
    if (!_isDragging) return;
    _isDragging = false;
    
    // 恢复最大化功能
    await windowManager.setMaximizable(true);
    // 贴边回弹
    await _snapToEdgeIfNeeded();
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
