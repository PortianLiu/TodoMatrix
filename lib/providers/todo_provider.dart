import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/storage_service.dart';

/// UUID 生成器
const _uuid = Uuid();

/// 存储服务 Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  final service = StorageService(
    onSaveError: (error) {
      // 可以在这里添加错误处理逻辑
    },
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// 应用数据状态 Provider
final appDataProvider = StateNotifierProvider<AppDataNotifier, AppData>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return AppDataNotifier(storageService);
});

/// 应用数据状态管理器
class AppDataNotifier extends StateNotifier<AppData> {
  final StorageService _storageService;
  bool _isLoading = false;

  AppDataNotifier(this._storageService) : super(AppData.empty());

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 加载数据
  Future<void> loadData() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final data = await _storageService.loadData();
      state = data;
    } finally {
      _isLoading = false;
    }
  }

  /// 触发自动保存
  void _triggerAutoSave() {
    _storageService.triggerAutoSave(state);
  }

  /// 更新最后修改时间
  AppData _updateLastModified(AppData data) {
    return data.copyWith(lastModified: DateTime.now());
  }

  // ==================== 列表操作 ====================

  /// 创建新列表
  void createList({String title = '新列表'}) {
    final now = DateTime.now();
    final newList = TodoList(
      id: _uuid.v4(),
      title: title,
      items: const [],
      createdAt: now,
      updatedAt: now,
      sortOrder: state.lists.length,
    );

    final newLists = [...state.lists, newList];
    final newLayout = state.layout.copyWith(
      listOrder: [...state.layout.listOrder, newList.id],
    );

    state = _updateLastModified(state.copyWith(
      lists: newLists,
      layout: newLayout,
    ));
    _triggerAutoSave();
  }

  /// 更新列表标题
  void updateListTitle(String listId, String newTitle) {
    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final updatedList = state.lists[listIndex].copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 删除列表
  void deleteList(String listId) {
    final newLists = state.lists.where((l) => l.id != listId).toList();
    final newListOrder = state.layout.listOrder.where((id) => id != listId).toList();

    state = _updateLastModified(state.copyWith(
      lists: newLists,
      layout: state.layout.copyWith(listOrder: newListOrder),
    ));
    _triggerAutoSave();
  }

  /// 更新列表底色
  void updateListColor(String listId, String? colorHex) {
    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final updatedList = state.lists[listIndex].copyWith(
      backgroundColor: colorHex,
      clearBackgroundColor: colorHex == null,
      updatedAt: DateTime.now(),
    );

    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 移动列表（重新排序）
  void moveList(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final listOrder = [...state.layout.listOrder];
    final item = listOrder.removeAt(oldIndex);
    listOrder.insert(newIndex, item);

    // 更新 sortOrder
    final newLists = state.lists.map((list) {
      final index = listOrder.indexOf(list.id);
      if (index != -1 && list.sortOrder != index) {
        return list.copyWith(sortOrder: index, updatedAt: DateTime.now());
      }
      return list;
    }).toList();

    state = _updateLastModified(state.copyWith(
      lists: newLists,
      layout: state.layout.copyWith(listOrder: listOrder),
    ));
    _triggerAutoSave();
  }

  // ==================== 待办项操作 ====================

  /// 添加待办项到列表
  void addTodoItem(String listId, String description) {
    if (description.trim().isEmpty) return;

    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final now = DateTime.now();
    final list = state.lists[listIndex];

    final newItem = TodoItem(
      id: _uuid.v4(),
      description: description.trim(),
      isCompleted: false,
      priority: Priority.medium,
      createdAt: now,
      updatedAt: now,
      sortOrder: list.items.length,
    );

    final updatedList = list.copyWith(
      items: [...list.items, newItem],
      updatedAt: now,
    );

    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 更新待办项描述
  void updateTodoDescription(String listId, String itemId, String description) {
    _updateTodoItem(listId, itemId, (item) => item.copyWith(
      description: description,
      updatedAt: DateTime.now(),
    ));
  }

  /// 切换待办项完成状态
  void toggleTodoCompleted(String listId, String itemId) {
    _updateTodoItem(listId, itemId, (item) => item.copyWith(
      isCompleted: !item.isCompleted,
      updatedAt: DateTime.now(),
    ));
  }

  /// 设置待办项优先级
  void setTodoPriority(String listId, String itemId, Priority priority) {
    _updateTodoItem(listId, itemId, (item) => item.copyWith(
      priority: priority,
      updatedAt: DateTime.now(),
    ));
  }

  /// 设置待办项截止日期
  void setTodoDueDate(String listId, String itemId, DateTime? dueDate) {
    _updateTodoItem(listId, itemId, (item) => item.copyWith(
      dueDate: dueDate,
      updatedAt: DateTime.now(),
      clearDueDate: dueDate == null,
    ));
  }

  /// 删除待办项
  void deleteTodoItem(String listId, String itemId) {
    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final list = state.lists[listIndex];
    final newItems = list.items.where((i) => i.id != itemId).toList();

    final updatedList = list.copyWith(
      items: newItems,
      updatedAt: DateTime.now(),
    );

    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 在列表内移动待办项
  void moveTodoItemInList(String listId, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final list = state.lists[listIndex];
    final items = [...list.items];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // 更新 sortOrder
    final now = DateTime.now();
    final updatedItems = items.asMap().entries.map((entry) {
      final i = entry.key;
      final todoItem = entry.value;
      if (todoItem.sortOrder != i) {
        return todoItem.copyWith(sortOrder: i, updatedAt: now);
      }
      return todoItem;
    }).toList();

    final updatedList = list.copyWith(items: updatedItems, updatedAt: now);
    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 跨列表移动待办项
  void moveTodoItemToList(
    String sourceListId,
    String targetListId,
    String itemId, {
    int? targetIndex,
  }) {
    if (sourceListId == targetListId) return;

    final sourceListIndex = state.lists.indexWhere((l) => l.id == sourceListId);
    final targetListIndex = state.lists.indexWhere((l) => l.id == targetListId);
    if (sourceListIndex == -1 || targetListIndex == -1) return;

    final sourceList = state.lists[sourceListIndex];
    final targetList = state.lists[targetListIndex];

    final itemIndex = sourceList.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final now = DateTime.now();
    final item = sourceList.items[itemIndex];

    // 从源列表移除
    final newSourceItems = [...sourceList.items];
    newSourceItems.removeAt(itemIndex);

    // 添加到目标列表
    final newTargetItems = [...targetList.items];
    final insertIndex = targetIndex ?? newTargetItems.length;
    final movedItem = item.copyWith(
      sortOrder: insertIndex,
      updatedAt: now,
    );
    newTargetItems.insert(insertIndex, movedItem);

    // 更新目标列表的 sortOrder
    final updatedTargetItems = newTargetItems.asMap().entries.map((entry) {
      final i = entry.key;
      final todoItem = entry.value;
      if (todoItem.sortOrder != i) {
        return todoItem.copyWith(sortOrder: i);
      }
      return todoItem;
    }).toList();

    final updatedSourceList = sourceList.copyWith(
      items: newSourceItems,
      updatedAt: now,
    );
    final updatedTargetList = targetList.copyWith(
      items: updatedTargetItems,
      updatedAt: now,
    );

    final newLists = [...state.lists];
    newLists[sourceListIndex] = updatedSourceList;
    newLists[targetListIndex] = updatedTargetList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  /// 辅助方法：更新单个待办项
  void _updateTodoItem(
    String listId,
    String itemId,
    TodoItem Function(TodoItem) updater,
  ) {
    final listIndex = state.lists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final list = state.lists[listIndex];
    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final updatedItem = updater(list.items[itemIndex]);
    final newItems = [...list.items];
    newItems[itemIndex] = updatedItem;

    final updatedList = list.copyWith(
      items: newItems,
      updatedAt: DateTime.now(),
    );

    final newLists = [...state.lists];
    newLists[listIndex] = updatedList;

    state = _updateLastModified(state.copyWith(lists: newLists));
    _triggerAutoSave();
  }

  // ==================== 布局操作 ====================

  /// 设置每行列数
  void setColumnsPerRow(int columns) {
    if (columns < 1 || columns > 10) return;

    final newLayout = state.layout.copyWith(columnsPerRow: columns);
    state = _updateLastModified(state.copyWith(layout: newLayout));
    _triggerAutoSave();
  }

  /// 设置列表高度
  void setListHeight(double height) {
    if (height < 200 || height > 800) return;

    final newLayout = state.layout.copyWith(listHeight: height);
    state = _updateLastModified(state.copyWith(layout: newLayout));
    _triggerAutoSave();
  }

  /// 更新列表排序顺序
  void updateListOrder(List<String> newOrder) {
    final now = DateTime.now();
    final newLayout = state.layout.copyWith(listOrder: newOrder);

    // 同时更新列表的 sortOrder
    final newLists = state.lists.map((list) {
      final index = newOrder.indexOf(list.id);
      if (index != -1 && list.sortOrder != index) {
        return list.copyWith(sortOrder: index, updatedAt: now);
      }
      return list;
    }).toList();

    state = _updateLastModified(state.copyWith(
      lists: newLists,
      layout: newLayout,
    ));
    _triggerAutoSave();
  }

  // ==================== 设置操作 ====================

  /// 设置主题模式
  void setThemeMode(ThemeMode themeMode) {
    final newSettings = state.settings.copyWith(themeMode: themeMode);
    state = _updateLastModified(state.copyWith(settings: newSettings));
    _triggerAutoSave();
  }

  /// 设置主题色
  void setThemeColor(String colorHex) {
    final newSettings = state.settings.copyWith(themeColor: colorHex);
    state = _updateLastModified(state.copyWith(settings: newSettings));
    _triggerAutoSave();
  }

  /// 更新应用设置
  void updateSettings(AppSettings newSettings) {
    state = _updateLastModified(state.copyWith(settings: newSettings));
    _triggerAutoSave();
  }

  // ==================== 数据导入导出 ====================

  /// 导出数据到文件
  Future<void> exportData(String path) async {
    await _storageService.exportToFile(path);
  }

  /// 从文件导入数据
  Future<void> importData(String path, {bool replace = false}) async {
    final importedData = await _storageService.importFromFile(path);

    if (replace) {
      state = importedData;
    } else {
      // 合并数据：添加不存在的列表
      final existingIds = state.lists.map((l) => l.id).toSet();
      final newLists = importedData.lists
          .where((l) => !existingIds.contains(l.id))
          .toList();

      if (newLists.isNotEmpty) {
        final mergedLists = [...state.lists, ...newLists];
        final mergedListOrder = [
          ...state.layout.listOrder,
          ...newLists.map((l) => l.id),
        ];

        state = _updateLastModified(state.copyWith(
          lists: mergedLists,
          layout: state.layout.copyWith(listOrder: mergedListOrder),
        ));
      }
    }

    _triggerAutoSave();
  }
}

// ==================== 便捷 Provider ====================

/// 获取所有列表（按排序顺序）
final sortedListsProvider = Provider<List<TodoList>>((ref) {
  final appData = ref.watch(appDataProvider);
  final listOrder = appData.layout.listOrder;

  // 按 listOrder 排序
  final listsMap = {for (var list in appData.lists) list.id: list};
  final sortedLists = <TodoList>[];

  for (final id in listOrder) {
    if (listsMap.containsKey(id)) {
      sortedLists.add(listsMap[id]!);
    }
  }

  // 添加不在 listOrder 中的列表
  for (final list in appData.lists) {
    if (!listOrder.contains(list.id)) {
      sortedLists.add(list);
    }
  }

  return sortedLists;
});

/// 获取指定列表
final todoListProvider = Provider.family<TodoList?, String>((ref, listId) {
  final appData = ref.watch(appDataProvider);
  try {
    return appData.lists.firstWhere((l) => l.id == listId);
  } catch (_) {
    return null;
  }
});

/// 获取指定待办项
final todoItemProvider = Provider.family<TodoItem?, ({String listId, String itemId})>((ref, params) {
  final list = ref.watch(todoListProvider(params.listId));
  if (list == null) return null;

  try {
    return list.items.firstWhere((i) => i.id == params.itemId);
  } catch (_) {
    return null;
  }
});

/// 获取当前主题模式
final themeModeProvider = Provider<ThemeMode>((ref) {
  final appData = ref.watch(appDataProvider);
  return appData.settings.themeMode;
});

/// 获取应用设置
final appSettingsProvider = Provider<AppSettings>((ref) {
  final appData = ref.watch(appDataProvider);
  return appData.settings;
});
