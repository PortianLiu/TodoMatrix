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

    // 验证应用标题显示
    expect(find.text('TodoMatrix - 待办事项管理'), findsOneWidget);
  });
}
