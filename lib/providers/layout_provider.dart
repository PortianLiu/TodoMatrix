import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_settings.dart';
import 'data_provider.dart';

/// 布局设置 Provider（从 LocalSettings 获取）
final layoutSettingsProvider = Provider<LocalSettings>((ref) {
  final data = ref.watch(dataProvider);
  return data.settings;
});

/// 布局控制器
class LayoutController {
  final Ref _ref;

  LayoutController(this._ref);

  /// 获取当前布局设置
  LocalSettings get layout => _ref.read(layoutSettingsProvider);

  /// 获取当前每行列数
  int get columnsPerRow => _ref.read(columnsPerRowProvider);

  /// 设置每行列数
  void setColumnsPerRow(int columns) {
    _ref.read(dataProvider.notifier).setColumnsPerRow(columns);
  }

  /// 获取列表排序顺序
  List<String> get listOrder => _ref.read(dataProvider).manifest.listOrder;

  /// 更新列表排序顺序
  void updateListOrder(List<String> newOrder) {
    _ref.read(dataProvider.notifier).updateListOrder(newOrder);
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
