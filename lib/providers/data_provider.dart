import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/sync_manifest.dart';
import '../models/local_settings.dart';
import '../models/todo_list.dart';
import '../models/todo_item.dart';
import '../services/sync_storage_service.dart';

/// UUID 生成器
const _uuid = Uuid();

/// 同步存储服务 Provider
final syncStorageProvider = Provider<SyncStorageService>((ref) {
  final service = SyncStorageService(
    onSaveError: (msg) => debugPrint('[DataProvider] 保存错误: $msg'),
    onSaveSuccess: () => debugPrint('[DataProvider] 保存成功'),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// 应用数据状态（包含清单和所有列表）
class AppDataState {
  final SyncManifest manifest;
  final Map<String, TodoList> lists;
  final LocalSettings settings;
  final bool isLoading;

  const AppDataState({
    required this.manifest,
    required this.lists,
    required this.settings,
    this.isLoading = false,
  });

  factory AppDataState.empty() {
    return AppDataState(
      manifest: SyncManifest.empty(),
      lists: const {},
      settings: const LocalSettings(),
    );
  }

  AppDataState copyWith({
    SyncManifest? manifest,
    Map<String, TodoList>? lists,
    LocalSettings? settings,
    bool? isLoading,
  }) {
    return AppDataState(
      manifest: manifest ?? this.manifest,
      lists: lists ?? this.lists,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 获取排序后的列表
  List<TodoList> get sortedLists {
    final result = <TodoList>[];
    for (final id in manifest.listOrder) {
      if (lists.containsKey(id)) {
        result.add(lists[id]!);
      }
    }
    // 添加不在 listOrder 中的列表
    for (final list in lists.values) {
      if (!manifest.listOrder.contains(list.id)) {
        result.add(list);
      }
    }
    return result;
  }
}

/// 应用数据 Provider
final dataProvider = StateNotifierProvider<DataNotifier, AppDataState>((ref) {
  final storage = ref.watch(syncStorageProvider);
  return DataNotifier(storage);
});

/// 数据状态管理器
class DataNotifier extends StateNotifier<AppDataState> {
  final SyncStorageService _storage;

  DataNotifier(this._storage) : super(AppDataState.empty());

  /// 加载数据
  /// 注意：此方法在 main.dart 中预调用，确保数据在应用启动前加载完成
  Future<void> loadData() async {
    // 如果已经有数据（非空列表或非默认设置），跳过重复加载
    if (state.lists.isNotEmpty || state.settings.themeColor != '9999ff') {
      debugPrint('[DataNotifier] 数据已加载，跳过重复加载');
      return;
    }
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      debugPrint('[DataNotifier] ========== 开始加载数据 ==========');
      
      // 尝试从旧版迁移
      final migrated = await _storage.migrateFromLegacy();
      debugPrint('[DataNotifier] 迁移结果: $migrated');

      // 加载清单
      final manifest = await _storage.loadManifest();
      debugPrint('[DataNotifier] 加载清单完成:');
      debugPrint('[DataNotifier]   - 列表数量: ${manifest.lists.length}');
      debugPrint('[DataNotifier]   - 列表顺序: ${manifest.listOrder}');
      for (final meta in manifest.lists) {
        debugPrint('[DataNotifier]   - 列表: ${meta.id} (${meta.title})');
      }

      // 加载所有列表
      final listsList = await _storage.loadAllLists(manifest);
      final lists = {for (var l in listsList) l.id: l};
      debugPrint('[DataNotifier] 加载列表完成:');
      debugPrint('[DataNotifier]   - 成功加载: ${lists.length} 个');
      for (final list in lists.values) {
        debugPrint('[DataNotifier]   - ${list.id}: ${list.title} (${list.items.length} 项)');
      }

      // 加载本地设置
      final settings = await _storage.loadLocalSettings();
      debugPrint('[DataNotifier] 加载设置完成:');
      debugPrint('[DataNotifier]   - themeColor: ${settings.themeColor}');
      debugPrint('[DataNotifier]   - deviceName: ${settings.deviceName}');
      debugPrint('[DataNotifier]   - columnsPerRow: ${settings.columnsPerRow}');
      debugPrint('[DataNotifier]   - listHeight: ${settings.listHeight}');
      debugPrint('[DataNotifier]   - syncEnabled: ${settings.syncEnabled}');
      debugPrint('[DataNotifier]   - windowX: ${settings.windowX}');
      debugPrint('[DataNotifier]   - windowY: ${settings.windowY}');

      state = AppDataState(
        manifest: manifest,
        lists: lists,
        settings: settings,
        isLoading: false,
      );
      
      debugPrint('[DataNotifier] ========== 数据加载完成 ==========');
      debugPrint('[DataNotifier] 最终状态: ${state.lists.length} 个列表');
    } catch (e, stackTrace) {
      debugPrint('[DataNotifier] 加载数据失败: $e');
      debugPrint('[DataNotifier] 堆栈: $stackTrace');
      // 加载失败时使用空数据，确保应用能正常启动
      state = AppDataState(
        manifest: SyncManifest.empty(),
        lists: const {},
        settings: const LocalSettings(),
        isLoading: false,
      );
    }
  }

  /// 数据变更回调（用于触发同步）
  void Function()? onDataChanged;

  /// 更新清单并保存
  void _updateManifest(SyncManifest manifest) {
    state = state.copyWith(
      manifest: manifest.copyWith(lastModified: DateTime.now()),
    );
    _storage.triggerManifestSave(state.manifest);
  }

  /// 更新列表并保存
  void _updateList(TodoList list) {
    final newLists = Map<String, TodoList>.from(state.lists);
    newLists[list.id] = list;
    state = state.copyWith(lists: newLists);
    _storage.triggerListSave(list);

    // 同步更新清单中的元信息
    final metaIndex = state.manifest.lists.indexWhere((m) => m.id == list.id);
    if (metaIndex != -1) {
      final newMetas = [...state.manifest.lists];
      newMetas[metaIndex] = ListMeta(
        id: list.id,
        title: list.title,
        sortOrder: list.sortOrder,
        updatedAt: list.updatedAt,
        backgroundColor: list.backgroundColor,
      );
      _updateManifest(state.manifest.copyWith(lists: newMetas));
    }
    
    // 通知数据变更
    onDataChanged?.call();
  }

  /// 更新设置并保存
  void _updateSettings(LocalSettings settings) {
    state = state.copyWith(settings: settings);
    _storage.triggerSettingsSave(settings);
  }

  // ==================== 列表操作 ====================

  /// 创建新列表
  void createList({String title = '新列表'}) {
    final now = DateTime.now();
    final id = _uuid.v4();
    final sortOrder = state.manifest.lists.length;

    final newList = TodoList(
      id: id,
      title: title,
      items: const [],
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
    );

    final newMeta = ListMeta(
      id: id,
      title: title,
      sortOrder: sortOrder,
      updatedAt: now,
    );

    // 更新状态
    final newLists = Map<String, TodoList>.from(state.lists);
    newLists[id] = newList;

    final newManifest = state.manifest.copyWith(
      lists: [...state.manifest.lists, newMeta],
      listOrder: [...state.manifest.listOrder, id],
      lastModified: now,
    );

    state = state.copyWith(lists: newLists, manifest: newManifest);

    // 保存
    _storage.triggerListSave(newList);
    _storage.triggerManifestSave(newManifest);

    debugPrint('[DataNotifier] 创建列表: $id');
  }

  /// 更新列表标题
  void updateListTitle(String listId, String newTitle) {
    final list = state.lists[listId];
    if (list == null) return;

    final updatedList = list.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    _updateList(updatedList);
  }

  /// 更新列表底色
  void updateListColor(String listId, String? colorHex) {
    final list = state.lists[listId];
    if (list == null) return;

    final updatedList = list.copyWith(
      backgroundColor: colorHex,
      clearBackgroundColor: colorHex == null,
      updatedAt: DateTime.now(),
    );
    _updateList(updatedList);
  }

  /// 删除列表
  void deleteList(String listId) {
    final now = DateTime.now();
    final newLists = Map<String, TodoList>.from(state.lists);
    newLists.remove(listId);

    final newMetas = state.manifest.lists.where((m) => m.id != listId).toList();
    final newOrder = state.manifest.listOrder.where((id) => id != listId).toList();

    // 添加墓碑记录
    final newDeletedItems = [
      ...state.manifest.deletedItems,
      DeletedItem(id: listId, deletedAt: now, type: 'list'),
    ];

    final newManifest = state.manifest.copyWith(
      lists: newMetas,
      listOrder: newOrder,
      lastModified: now,
      deletedItems: newDeletedItems,
    );

    state = state.copyWith(lists: newLists, manifest: newManifest);

    // 删除文件并保存清单
    _storage.deleteList(listId);
    _storage.triggerManifestSave(newManifest);

    debugPrint('[DataNotifier] 删除列表: $listId');
  }

  // ==================== 待办项操作 ====================

  /// 添加待办项
  void addTodoItem(String listId, String description) {
    if (description.trim().isEmpty) return;

    final list = state.lists[listId];
    if (list == null) return;

    final now = DateTime.now();
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
    _updateList(updatedList);
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
      clearDueDate: dueDate == null,
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除待办项
  void deleteTodoItem(String listId, String itemId) {
    final list = state.lists[listId];
    if (list == null) return;

    final now = DateTime.now();
    final newItems = list.items.where((i) => i.id != itemId).toList();
    final updatedList = list.copyWith(
      items: newItems,
      updatedAt: now,
    );
    _updateList(updatedList);

    // 添加墓碑记录
    final newDeletedItems = [
      ...state.manifest.deletedItems,
      DeletedItem(id: itemId, deletedAt: now, type: 'item', listId: listId),
    ];
    _updateManifest(state.manifest.copyWith(deletedItems: newDeletedItems));
  }

  /// 在列表内移动待办项
  void moveTodoItemInList(String listId, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final list = state.lists[listId];
    if (list == null) return;

    final items = [...list.items];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

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
    _updateList(updatedList);
  }

  /// 跨列表移动待办项
  void moveTodoItemToList(
    String sourceListId,
    String targetListId,
    String itemId, {
    int? targetIndex,
  }) {
    if (sourceListId == targetListId) return;

    final sourceList = state.lists[sourceListId];
    final targetList = state.lists[targetListId];
    if (sourceList == null || targetList == null) return;

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
    final movedItem = item.copyWith(sortOrder: insertIndex, updatedAt: now);
    newTargetItems.insert(insertIndex, movedItem);

    // 更新 sortOrder
    final updatedTargetItems = newTargetItems.asMap().entries.map((entry) {
      final i = entry.key;
      final todoItem = entry.value;
      if (todoItem.sortOrder != i) {
        return todoItem.copyWith(sortOrder: i);
      }
      return todoItem;
    }).toList();

    final updatedSourceList = sourceList.copyWith(items: newSourceItems, updatedAt: now);
    final updatedTargetList = targetList.copyWith(items: updatedTargetItems, updatedAt: now);

    _updateList(updatedSourceList);
    _updateList(updatedTargetList);
  }

  /// 辅助方法：更新单个待办项
  void _updateTodoItem(
    String listId,
    String itemId,
    TodoItem Function(TodoItem) updater,
  ) {
    final list = state.lists[listId];
    if (list == null) return;

    final itemIndex = list.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final updatedItem = updater(list.items[itemIndex]);
    final newItems = [...list.items];
    newItems[itemIndex] = updatedItem;

    final updatedList = list.copyWith(
      items: newItems,
      updatedAt: DateTime.now(),
    );
    _updateList(updatedList);
  }

  // ==================== 布局操作 ====================

  /// 设置每行列数
  void setColumnsPerRow(int columns) {
    if (columns < 1 || columns > 10) return;
    _updateSettings(state.settings.copyWith(columnsPerRow: columns));
  }

  /// 设置列表高度
  void setListHeight(double height) {
    if (height < 200 || height > 800) return;
    _updateSettings(state.settings.copyWith(listHeight: height));
  }

  /// 更新列表排序顺序
  void updateListOrder(List<String> newOrder) {
    final now = DateTime.now();

    // 更新清单
    final newManifest = state.manifest.copyWith(
      listOrder: newOrder,
      lastModified: now,
    );
    _updateManifest(newManifest);

    // 更新各列表的 sortOrder
    for (var i = 0; i < newOrder.length; i++) {
      final list = state.lists[newOrder[i]];
      if (list != null && list.sortOrder != i) {
        final updatedList = list.copyWith(sortOrder: i, updatedAt: now);
        _updateList(updatedList);
      }
    }
  }

  // ==================== 设置操作 ====================

  /// 设置主题模式
  void setThemeMode(ThemeMode themeMode) {
    _updateSettings(state.settings.copyWith(themeMode: themeMode));
  }

  /// 设置主题色
  void setThemeColor(String colorHex) {
    _updateSettings(state.settings.copyWith(themeColor: colorHex));
  }

  /// 更新设置
  void updateSettings(LocalSettings newSettings) {
    _updateSettings(newSettings);
  }

  /// 应用同步后的数据（由 SyncProvider 调用）
  void applySyncedData(SyncManifest manifest, List<TodoList> lists) {
    debugPrint('[DataNotifier] 应用同步数据: ${lists.length} 个列表');
    
    final newLists = {for (var l in lists) l.id: l};
    
    state = state.copyWith(
      manifest: manifest,
      lists: newLists,
    );

    // 保存所有数据
    _storage.triggerManifestSave(manifest);
    for (final list in lists) {
      _storage.triggerListSave(list);
    }
    
    debugPrint('[DataNotifier] 同步数据已应用并保存');
  }
}


// ==================== 便捷 Provider ====================

/// 获取排序后的列表
final sortedListsProvider = Provider<List<TodoList>>((ref) {
  final data = ref.watch(dataProvider);
  return data.sortedLists;
});

/// 获取指定列表
final todoListProvider = Provider.family<TodoList?, String>((ref, listId) {
  final data = ref.watch(dataProvider);
  return data.lists[listId];
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
  final data = ref.watch(dataProvider);
  return data.settings.themeMode;
});

/// 获取本地设置
final localSettingsProvider = Provider<LocalSettings>((ref) {
  final data = ref.watch(dataProvider);
  return data.settings;
});

/// 获取每行列数
final columnsPerRowProvider = Provider<int>((ref) {
  final data = ref.watch(dataProvider);
  return data.settings.columnsPerRow;
});

/// 获取列表高度
final listHeightProvider = Provider<double>((ref) {
  final data = ref.watch(dataProvider);
  return data.settings.listHeight;
});
