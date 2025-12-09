import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/todo_provider.dart';
import 'services/window_service.dart';
import 'widgets/main_screen.dart';

/// TodoMatrix 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 平台初始化窗口服务
  if (!kIsWeb && Platform.isWindows) {
    await WindowService.instance.initialize();

    // 设置退出回调
    WindowService.instance.onExitApp = () {
      WindowService.instance.destroy();
      exit(0);
    };
  }

  runApp(
    const ProviderScope(
      child: TodoMatrixApp(),
    ),
  );
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
    final settings = ref.watch(appSettingsProvider);
    final seedColor = hexToColor(settings.themeColor);

    return MaterialApp(
      title: 'TodoMatrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
