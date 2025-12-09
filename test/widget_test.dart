import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_matrix/main.dart';

void main() {
  testWidgets('TodoMatrix 应用启动测试', (WidgetTester tester) async {
    // 构建应用
    await tester.pumpWidget(
      const ProviderScope(
        child: TodoMatrixApp(),
      ),
    );

    // 等待初始帧渲染
    await tester.pump();

    // 验证有 CircularProgressIndicator 或 AppBar
    final hasProgress = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasAppBar = find.text('TodoMatrix').evaluate().isNotEmpty;

    // 应用应该显示加载指示器或主界面
    expect(hasProgress || hasAppBar, isTrue);
  });
}
