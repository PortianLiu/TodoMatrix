import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'todo_provider.dart';

/// 布局设置 Provider
final layoutSettingsProvider = Provider<LayoutSettings>((ref) {
  final appData = ref.watch(appDataProvider);
  return appData.layout;
});

/// 每行列数 Provider
final columnsPerRowProvider = Provider<int>((ref) {
  final layout = ref.watch(layoutSettingsProvider);
  return layout.columnsPerRow;
});

/// 布局控制器
class LayoutController {
  final Ref _ref;

  LayoutController(this._ref);

  /// 获取当前布局设置
  LayoutSettings get layout => _ref.read(layoutSettingsProvider);

  /// 获取当前每行列数
  int get columnsPerRow => _ref.read(columnsPerRowProvider);

  /// 设置每行列数
  void setColumnsPerRow(int columns) {
    _ref.read(appDataProvider.notifier).setColumnsPerRow(columns);
  }

  /// 移动列表到新位置
  void moveList(int oldIndex, int newIndex) {
    _ref.read(appDataProvider.notifier).moveList(oldIndex, newIndex);
  }

  /// 获取列表排序顺序
  List<String> get listOrder => layout.listOrder;

  /// 更新列表排序顺序
  void updateListOrder(List<String> newOrder) {
    _ref.read(appDataProvider.notifier).updateListOrder(newOrder);
  }
}

/// 布局控制器 Provider
final layoutControllerProvider = Provider<LayoutController>((ref) {
  return LayoutController(ref);
});

/// 计算网格布局的列数（响应式）
/// 根据可用宽度和最小列宽计算
int calculateResponsiveColumns(double availableWidth, {
  double minColumnWidth = 280,
  int maxColumns = 10,
  int? preferredColumns,
}) {
  if (preferredColumns != null && preferredColumns > 0) {
    // 如果有首选列数，检查是否可行
    final columnWidth = availableWidth / preferredColumns;
    if (columnWidth >= minColumnWidth) {
      return preferredColumns;
    }
  }

  // 计算可容纳的最大列数
  int columns = (availableWidth / minColumnWidth).floor();
  columns = columns.clamp(1, maxColumns);

  return columns;
}
