import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/todo_provider.dart';
import 'widgets/main_screen.dart';

/// TodoMatrix 应用入口
void main() {
  runApp(
    const ProviderScope(
      child: TodoMatrixApp(),
    ),
  );
}

/// TodoMatrix 主应用
class TodoMatrixApp extends ConsumerWidget {
  const TodoMatrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题模式变化
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'TodoMatrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
