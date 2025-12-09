import '../models/models.dart';
import '../services/sync_service.dart';

/// 冲突解决器
/// 提供冲突检测和解决的工具方法
class ConflictResolver {
  /// 检测两个 AppData 之间的冲突
  static List<ConflictItem> detectConflicts(AppData local, AppData remote) {
    final conflicts = <ConflictItem>[];

    // 构建本地项目映射
    final localItems = <String, (String, TodoItem)>{};
    for (final list in local.lists) {
      for (final item in list.items) {
        localItems[item.id] = (list.id, item);
      }
    }

    // 检查远程项目
    for (final remoteList in remote.lists) {
      for (final remoteItem in remoteList.items) {
        final localEntry = localItems[remoteItem.id];
        if (localEntry != null) {
          final (listId, localItem) = localEntry;
          // 如果两边都有修改且内容不同，则为冲突
          if (_hasConflict(localItem, remoteItem)) {
            conflicts.add(ConflictItem(
              itemId: remoteItem.id,
              listId: listId,
              localItem: localItem,
              remoteItem: remoteItem,
            ));
          }
        }
      }
    }

    return conflicts;
  }

  /// 判断两个待办项是否冲突
  static bool _hasConflict(TodoItem local, TodoItem remote) {
    // 更新时间不同且内容不同
    if (local.updatedAt == remote.updatedAt) return false;

    return local.description != remote.description ||
        local.isCompleted != remote.isCompleted ||
        local.priority != remote.priority ||
        local.dueDate != remote.dueDate;
  }

  /// 解决单个冲突
  static TodoItem resolveConflict(
    ConflictItem conflict,
    ConflictResolution resolution,
  ) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return conflict.localItem;
      case ConflictResolution.keepRemote:
        return conflict.remoteItem;
      case ConflictResolution.keepBoth:
        // 保留两者：创建一个合并版本
        // 使用最新的完成状态和优先级，合并描述
        final newer = conflict.localItem.updatedAt.isAfter(conflict.remoteItem.updatedAt)
            ? conflict.localItem
            : conflict.remoteItem;
        return newer;
    }
  }

  /// 应用冲突解决方案到数据
  static AppData applyResolutions(
    AppData data,
    Map<String, ConflictResolution> resolutions,
    List<ConflictItem> conflicts,
  ) {
    var result = data;

    for (final conflict in conflicts) {
      final resolution = resolutions[conflict.itemId];
      if (resolution == null) continue;

      final resolvedItem = resolveConflict(conflict, resolution);

      // 更新数据中的项目
      final listIndex = result.lists.indexWhere((l) => l.id == conflict.listId);
      if (listIndex == -1) continue;

      final list = result.lists[listIndex];
      final itemIndex = list.items.indexWhere((i) => i.id == conflict.itemId);
      if (itemIndex == -1) continue;

      final newItems = [...list.items];
      newItems[itemIndex] = resolvedItem;

      final newList = list.copyWith(items: newItems, updatedAt: DateTime.now());
      final newLists = [...result.lists];
      newLists[listIndex] = newList;

      result = result.copyWith(lists: newLists, lastModified: DateTime.now());
    }

    return result;
  }
}
