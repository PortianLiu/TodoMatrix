import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'discovery_service.dart';

/// 同步事件类型
enum SyncEventType {
  connecting,
  connected,
  exchangingData,
  conflictDetected,
  completed,
  failed,
}

/// 同步事件
class SyncEvent {
  final SyncEventType type;
  final String? message;
  final SyncResult? result;
  final List<ConflictItem>? conflicts;

  SyncEvent({
    required this.type,
    this.message,
    this.result,
    this.conflicts,
  });
}

/// 同步结果
class SyncResult {
  final int added;
  final int updated;
  final int deleted;
  final DateTime syncTime;

  SyncResult({
    required this.added,
    required this.updated,
    required this.deleted,
    required this.syncTime,
  });

  @override
  String toString() => '新增: $added, 更新: $updated, 删除: $deleted';
}

/// 冲突项
class ConflictItem {
  final String itemId;
  final String listId;
  final TodoItem localItem;
  final TodoItem remoteItem;

  ConflictItem({
    required this.itemId,
    required this.listId,
    required this.localItem,
    required this.remoteItem,
  });
}


/// 冲突解决方式
enum ConflictResolution {
  keepLocal,
  keepRemote,
  keepBoth,
}

/// 同步服务
/// 使用 TCP 连接进行数据同步
class SyncService {
  static const int syncPort = 45679;
  static const Duration connectionTimeout = Duration(seconds: 10);

  final String _deviceId;
  ServerSocket? _server;
  Socket? _activeConnection;

  final _eventController = StreamController<SyncEvent>.broadcast();

  /// 同步事件流
  Stream<SyncEvent> get syncEvents => _eventController.stream;

  /// 本地数据获取回调
  AppData Function()? getLocalData;

  /// 数据更新回调
  void Function(AppData)? onDataUpdated;

  SyncService({required String deviceId}) : _deviceId = deviceId;

  /// 启动同步服务器（监听连接）
  Future<void> startServer() async {
    if (_server != null) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, syncPort);
      _server!.listen(_handleIncomingConnection);
    } catch (e) {
      print('Sync server start failed: $e');
    }
  }

  /// 停止同步服务器
  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  /// 处理传入连接
  void _handleIncomingConnection(Socket socket) async {
    _activeConnection = socket;
    _emitEvent(SyncEventType.connected, message: '收到同步请求');

    try {
      await _handleSyncSession(socket, isInitiator: false);
    } catch (e) {
      _emitEvent(SyncEventType.failed, message: '同步失败: $e');
    } finally {
      await socket.close();
      _activeConnection = null;
    }
  }

  /// 发起同步
  Future<void> startSync(DeviceInfo target) async {
    if (_activeConnection != null) {
      _emitEvent(SyncEventType.failed, message: '已有同步进行中');
      return;
    }

    _emitEvent(SyncEventType.connecting, message: '正在连接 ${target.deviceName}...');

    try {
      final socket = await Socket.connect(
        target.address,
        target.port,
        timeout: connectionTimeout,
      );

      _activeConnection = socket;
      _emitEvent(SyncEventType.connected, message: '已连接到 ${target.deviceName}');

      await _handleSyncSession(socket, isInitiator: true);
    } catch (e) {
      _emitEvent(SyncEventType.failed, message: '连接失败: $e');
    } finally {
      _activeConnection?.close();
      _activeConnection = null;
    }
  }

  /// 处理同步会话
  Future<void> _handleSyncSession(Socket socket, {required bool isInitiator}) async {
    final localData = getLocalData?.call();
    if (localData == null) {
      _emitEvent(SyncEventType.failed, message: '无法获取本地数据');
      return;
    }

    _emitEvent(SyncEventType.exchangingData, message: '正在交换数据...');

    // 发送本地数据
    final localJson = jsonEncode({
      'type': 'data',
      'deviceId': _deviceId,
      'snapshot': localData.toJson(),
    });
    socket.write('$localJson\n');
    await socket.flush();

    // 接收远程数据
    final remoteDataStr = await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(connectionTimeout);

    final remoteMessage = jsonDecode(remoteDataStr) as Map<String, dynamic>;
    if (remoteMessage['type'] != 'data') {
      _emitEvent(SyncEventType.failed, message: '无效的同步数据');
      return;
    }

    final remoteData = AppData.fromJson(remoteMessage['snapshot'] as Map<String, dynamic>);

    // 检测冲突并合并数据
    final conflicts = _detectConflicts(localData, remoteData);

    if (conflicts.isNotEmpty) {
      _emitEvent(SyncEventType.conflictDetected, conflicts: conflicts);
      // 简单处理：保留本地版本
      // 实际应用中应该让用户选择
    }

    // 合并数据
    final mergedData = _mergeData(localData, remoteData);
    final result = _calculateSyncResult(localData, mergedData);

    // 更新本地数据
    onDataUpdated?.call(mergedData);

    _emitEvent(SyncEventType.completed, result: result);
  }


  /// 检测冲突
  List<ConflictItem> _detectConflicts(AppData local, AppData remote) {
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
          if (localItem.updatedAt != remoteItem.updatedAt &&
              localItem.description != remoteItem.description) {
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

  /// 合并数据（简单策略：以最新修改时间为准）
  AppData _mergeData(AppData local, AppData remote) {
    final mergedLists = <TodoList>[];
    final processedListIds = <String>{};

    // 处理本地列表
    for (final localList in local.lists) {
      final remoteList = remote.lists.where((l) => l.id == localList.id).firstOrNull;

      if (remoteList == null) {
        // 仅本地存在
        mergedLists.add(localList);
      } else {
        // 两边都存在，合并
        mergedLists.add(_mergeList(localList, remoteList));
      }
      processedListIds.add(localList.id);
    }

    // 添加仅远程存在的列表
    for (final remoteList in remote.lists) {
      if (!processedListIds.contains(remoteList.id)) {
        mergedLists.add(remoteList);
      }
    }

    // 更新 listOrder
    final mergedListOrder = <String>[];
    for (final id in local.layout.listOrder) {
      if (mergedLists.any((l) => l.id == id)) {
        mergedListOrder.add(id);
      }
    }
    for (final list in mergedLists) {
      if (!mergedListOrder.contains(list.id)) {
        mergedListOrder.add(list.id);
      }
    }

    return local.copyWith(
      lists: mergedLists,
      layout: local.layout.copyWith(listOrder: mergedListOrder),
      lastModified: DateTime.now(),
    );
  }

  /// 合并单个列表
  TodoList _mergeList(TodoList local, TodoList remote) {
    final mergedItems = <TodoItem>[];
    final processedItemIds = <String>{};

    // 处理本地项目
    for (final localItem in local.items) {
      final remoteItem = remote.items.where((i) => i.id == localItem.id).firstOrNull;

      if (remoteItem == null) {
        mergedItems.add(localItem);
      } else {
        // 保留最新的
        mergedItems.add(
          localItem.updatedAt.isAfter(remoteItem.updatedAt) ? localItem : remoteItem,
        );
      }
      processedItemIds.add(localItem.id);
    }

    // 添加仅远程存在的项目
    for (final remoteItem in remote.items) {
      if (!processedItemIds.contains(remoteItem.id)) {
        mergedItems.add(remoteItem);
      }
    }

    // 按 sortOrder 排序
    mergedItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return local.copyWith(
      items: mergedItems,
      title: local.updatedAt.isAfter(remote.updatedAt) ? local.title : remote.title,
      updatedAt: DateTime.now(),
    );
  }

  /// 计算同步结果
  SyncResult _calculateSyncResult(AppData before, AppData after) {
    final beforeItemIds = <String>{};
    final afterItemIds = <String>{};

    for (final list in before.lists) {
      for (final item in list.items) {
        beforeItemIds.add(item.id);
      }
    }

    for (final list in after.lists) {
      for (final item in list.items) {
        afterItemIds.add(item.id);
      }
    }

    final added = afterItemIds.difference(beforeItemIds).length;
    final deleted = beforeItemIds.difference(afterItemIds).length;
    final updated = afterItemIds.intersection(beforeItemIds).length;

    return SyncResult(
      added: added,
      updated: updated,
      deleted: deleted,
      syncTime: DateTime.now(),
    );
  }

  /// 发送事件
  void _emitEvent(SyncEventType type, {
    String? message,
    SyncResult? result,
    List<ConflictItem>? conflicts,
  }) {
    _eventController.add(SyncEvent(
      type: type,
      message: message,
      result: result,
      conflicts: conflicts,
    ));
  }

  /// 停止当前同步
  Future<void> stopSync() async {
    await _activeConnection?.close();
    _activeConnection = null;
  }

  /// 销毁服务
  void dispose() {
    stopServer();
    stopSync();
    _eventController.close();
  }
}
