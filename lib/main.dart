import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/data_provider.dart';
import 'providers/sync_provider.dart';
import 'services/window_service.dart';
import 'widgets/main_screen.dart';

/// 全局 ProviderContainer（用于在 main 中访问 provider）
late ProviderContainer _container;

/// TodoMatrix 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 创建 ProviderContainer
  _container = ProviderContainer();

  // 预加载数据（在窗口初始化之前）
  // 这样可以确保设置数据在应用启动时就已经加载完成
  debugPrint('[Main] 开始预加载数据...');
  await _container.read(dataProvider.notifier).loadData();
  debugPrint('[Main] 数据预加载完成');

  // 如果同步功能已启用，初始化同步服务并开始监听
  final settings = _container.read(localSettingsProvider);
  if (settings.syncEnabled) {
    debugPrint('[Main] 同步功能已启用，初始化同步服务...');
    final syncNotifier = _container.read(syncProvider.notifier);
    await syncNotifier.initialize(settings.deviceName);
    await syncNotifier.startListening();
    // 启动时发起一次广播和同步
    await syncNotifier.broadcastAndSync();
    debugPrint('[Main] 同步服务初始化完成');
  }

  // Windows 平台初始化窗口服务
  if (!kIsWeb && Platform.isWindows) {
    await WindowService.instance.initialize();

    // 设置退出回调
    WindowService.instance.onExitApp = () {
      WindowService.instance.destroy();
      _container.dispose();
      exit(0);
    };
    
    // 使用已加载的设置恢复窗口位置
    await _restoreWindowBounds();
    
    // 设置窗口位置/大小变化回调
    WindowService.instance.onWindowBoundsChanged = _onWindowBoundsChanged;
  }

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const TodoMatrixApp(),
    ),
  );
}

/// 恢复保存的窗口位置和大小
Future<void> _restoreWindowBounds() async {
  try {
    // 使用已加载的设置（不再创建新的存储服务实例）
    final settings = _container.read(localSettingsProvider);
    debugPrint('[Main] 恢复窗口位置: x=${settings.windowX}, y=${settings.windowY}, w=${settings.windowWidth}, h=${settings.windowHeight}');
    
    // 恢复窗口位置和大小
    await WindowService.instance.restoreWindowBounds(
      x: settings.windowX,
      y: settings.windowY,
      width: settings.windowWidth,
      height: settings.windowHeight,
    );
  } catch (e) {
    debugPrint('[Main] 恢复窗口位置失败: $e');
  }
}

/// 窗口位置/大小变化时保存
void _onWindowBoundsChanged(double x, double y, double width, double height) {
  try {
    final notifier = _container.read(dataProvider.notifier);
    final currentSettings = _container.read(localSettingsProvider);
    
    // 只有当位置或大小真正变化时才保存
    if (currentSettings.windowX != x ||
        currentSettings.windowY != y ||
        currentSettings.windowWidth != width ||
        currentSettings.windowHeight != height) {
      notifier.updateSettings(currentSettings.copyWith(
        windowX: x,
        windowY: y,
        windowWidth: width,
        windowHeight: height,
      ));
    }
  } catch (e) {
    // 忽略错误（可能是初始化阶段）
  }
}

/// 从十六进制字符串解析颜色
Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// TodoMatrix 主应用
class TodoMatrixApp extends ConsumerWidget {
  const TodoMatrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题模式和主题色变化
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(localSettingsProvider);
    final seedColor = hexToColor(settings.themeColor);

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'TodoMatrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: lightColorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.primaryContainer,
          foregroundColor: lightColorScheme.onPrimaryContainer,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: lightColorScheme.onPrimary,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: darkColorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkColorScheme.primaryContainer,
          foregroundColor: darkColorScheme.onPrimaryContainer,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: darkColorScheme.primary,
            foregroundColor: darkColorScheme.onPrimary,
          ),
        ),
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
