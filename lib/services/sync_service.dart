import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/sync_manifest.dart';
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
  final int listsAdded;
  final int listsUpdated;
  final int itemsAdded;
  final int itemsUpdated;
  final DateTime syncTime;

  SyncResult({
    required this.listsAdded,
    required this.listsUpdated,
    required this.itemsAdded,
    required this.itemsUpdated,
    required this.syncTime,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (listsAdded > 0) parts.add('新增 $listsAdded 个列表');
    if (listsUpdated > 0) parts.add('更新 $listsUpdated 个列表');
    if (itemsAdded > 0) parts.add('新增 $itemsAdded 个待办');
    if (itemsUpdated > 0) parts.add('更新 $itemsUpdated 个待办');
    return parts.isEmpty ? '数据已是最新' : parts.join(', ');
  }
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

/// 同步数据包（用于网络传输）
class SyncDataPacket {
  final String deviceId;
  final SyncManifest manifest;
  final List<TodoList> lists;

  SyncDataPacket({
    required this.deviceId,
    required this.manifest,
    required this.lists,
  });

  Map<String, dynamic> toJson() => {
    'type': 'sync_data',
    'deviceId': deviceId,
    'manifest': manifest.toJson(),
    'lists': lists.map((l) => l.toJson()).toList(),
  };

  factory SyncDataPacket.fromJson(Map<String, dynamic> json) {
    return SyncDataPacket(
      deviceId: json['deviceId'] as String,
      manifest: SyncManifest.fromJson(json['manifest'] as Map<String, dynamic>),
      lists: (json['lists'] as List<dynamic>)
          .map((e) => TodoList.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 冲突解决方式
enum ConflictResolution {
  keepLocal,
  keepRemote,
  keepBoth,
}

/// 合并数据结果（内部使用）
class _MergeResult {
  final SyncManifest manifest;
  final List<TodoList> lists;
  final SyncResult result;

  _MergeResult({
    required this.manifest,
    required this.lists,
    required this.result,
  });
}

/// 列表合并结果（内部使用）
class _ListMergeResult {
  final TodoList list;
  final int itemsAdded;
  final int itemsUpdated;
  final int itemsDeleted;

  _ListMergeResult({
    required this.list,
    required this.itemsAdded,
    required this.itemsUpdated,
    this.itemsDeleted = 0,
  });
}

/// 同步服务
/// 使用 TCP 连接进行数据同步
class SyncService {
  static const int syncPort = 45679;
  static const Duration connectionTimeout = Duration(seconds: 10);

  // ignore: unused_field
  final String _deviceId;
  ServerSocket? _server;
  Socket? _activeConnection;

  final _eventController = StreamController<SyncEvent>.broadcast();

  /// 同步事件流
  Stream<SyncEvent> get syncEvents => _eventController.stream;

  /// 获取本地同步数据的回调
  SyncDataPacket Function()? getLocalSyncData;

  /// 数据更新回调（合并后的清单和列表）
  void Function(SyncManifest manifest, List<TodoList> lists)? onDataUpdated;

  SyncService({required String deviceId}) : _deviceId = deviceId;

  /// 启动同步服务器（监听连接）
  Future<void> startServer() async {
    if (_server != null) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, syncPort);
      _server!.listen(_handleIncomingConnection);
    } catch (e) {
      debugPrint('[SyncService] 服务器启动失败: $e');
    }
  }

  /// 停止同步服务器
  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  /// 连接成功回调（用于通知发现服务添加设备）
  void Function(String deviceId, String deviceName, InternetAddress address)? onDeviceConnected;

  /// 处理传入连接
  void _handleIncomingConnection(Socket socket) async {
    _activeConnection = socket;
    _emitEvent(SyncEventType.connected, message: '收到来自 ${socket.remoteAddress.address} 的同步请求');

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
    final localPacket = getLocalSyncData?.call();
    if (localPacket == null) {
      _emitEvent(SyncEventType.failed, message: '无法获取本地数据');
      return;
    }

    _emitEvent(SyncEventType.exchangingData, message: '正在交换数据...');

    try {
      // 收集接收到的数据
      final buffer = StringBuffer();
      final completer = Completer<String>();
      
      // 监听数据
      final subscription = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
        (data) {
          buffer.write(data);
          // 检查是否收到完整的一行（以换行符结尾）
          final content = buffer.toString();
          if (content.contains('\n')) {
            final line = content.split('\n').first;
            if (!completer.isCompleted) {
              completer.complete(line);
            }
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          // 连接关闭时，如果还没完成，检查缓冲区
          if (!completer.isCompleted) {
            final content = buffer.toString().trim();
            if (content.isNotEmpty) {
              completer.complete(content);
            } else {
              completer.completeError('连接已关闭，未收到数据');
            }
          }
        },
      );

      // 发送本地数据
      final localJson = jsonEncode(localPacket.toJson());
      socket.write('$localJson\n');
      await socket.flush();
      debugPrint('[SyncService] 已发送本地数据，${localPacket.lists.length} 个列表');

      // 等待接收远程数据
      final remoteDataStr = await completer.future.timeout(connectionTimeout);
      await subscription.cancel();

      debugPrint('[SyncService] 收到远程数据: ${remoteDataStr.length} 字节');

      final remoteMessage = jsonDecode(remoteDataStr) as Map<String, dynamic>;
      if (remoteMessage['type'] != 'sync_data') {
        _emitEvent(SyncEventType.failed, message: '无效的同步数据类型');
        return;
      }

      final remotePacket = SyncDataPacket.fromJson(remoteMessage);
      debugPrint('[SyncService] 解析远程数据成功，${remotePacket.lists.length} 个列表');

      // 通知发现服务添加/更新设备（被动方也能知道对方存在）
      if (!isInitiator && socket.remoteAddress != null) {
        onDeviceConnected?.call(
          remotePacket.deviceId,
          remotePacket.deviceId, // 使用 deviceId 作为名称（实际名称在广播中）
          socket.remoteAddress,
        );
      }

      // 合并数据
      final mergeResult = _mergeData(localPacket, remotePacket);
      
      // 更新本地数据
      onDataUpdated?.call(mergeResult.manifest, mergeResult.lists);

      _emitEvent(SyncEventType.completed, result: mergeResult.result);
    } catch (e, stackTrace) {
      debugPrint('[SyncService] 同步会话失败: $e');
      debugPrint('[SyncService] 堆栈: $stackTrace');
      _emitEvent(SyncEventType.failed, message: '同步失败: $e');
    }
  }


  /// 合并数据（以最新修改时间为准，支持删除同步）
  _MergeResult _mergeData(SyncDataPacket local, SyncDataPacket remote) {
    final mergedLists = <TodoList>[];
    final processedListIds = <String>{};
    
    // 统计变更
    int listsAdded = 0;
    int listsUpdated = 0;
    int itemsAdded = 0;
    int itemsUpdated = 0;
    int listsDeleted = 0;
    int itemsDeleted = 0;

    // 合并墓碑记录（已删除项目）
    final allDeletedItems = <String, DeletedItem>{};
    for (final item in local.manifest.deletedItems) {
      allDeletedItems[item.id] = item;
    }
    for (final item in remote.manifest.deletedItems) {
      // 如果两边都有删除记录，保留较新的
      final existing = allDeletedItems[item.id];
      if (existing == null || item.deletedAt.isAfter(existing.deletedAt)) {
        allDeletedItems[item.id] = item;
      }
    }

    // 已删除的列表 ID 集合
    final deletedListIds = allDeletedItems.entries
        .where((e) => e.value.type == 'list')
        .map((e) => e.key)
        .toSet();

    // 已删除的待办项 ID 集合
    final deletedItemIds = allDeletedItems.entries
        .where((e) => e.value.type == 'item')
        .map((e) => e.key)
        .toSet();

    // 构建远程列表映射
    final remoteListMap = {for (var l in remote.lists) l.id: l};

    // 处理本地列表
    for (final localList in local.lists) {
      // 检查是否被删除
      if (deletedListIds.contains(localList.id)) {
        // 检查删除时间是否晚于列表更新时间
        final deleteRecord = allDeletedItems[localList.id]!;
        if (deleteRecord.deletedAt.isAfter(localList.updatedAt)) {
          listsDeleted++;
          processedListIds.add(localList.id);
          continue; // 跳过已删除的列表
        }
      }

      final remoteList = remoteListMap[localList.id];

      if (remoteList == null) {
        // 仅本地存在，过滤已删除的待办项
        final filteredList = _filterDeletedItems(localList, deletedItemIds, allDeletedItems);
        mergedLists.add(filteredList.list);
        itemsDeleted += filteredList.itemsDeleted;
      } else {
        // 两边都存在，合并
        final mergeListResult = _mergeList(localList, remoteList, deletedItemIds, allDeletedItems);
        mergedLists.add(mergeListResult.list);
        if (mergeListResult.itemsAdded > 0 || mergeListResult.itemsUpdated > 0) {
          listsUpdated++;
        }
        itemsAdded += mergeListResult.itemsAdded;
        itemsUpdated += mergeListResult.itemsUpdated;
        itemsDeleted += mergeListResult.itemsDeleted;
      }
      processedListIds.add(localList.id);
    }

    // 添加仅远程存在的列表（排除已删除的）
    for (final remoteList in remote.lists) {
      if (!processedListIds.contains(remoteList.id)) {
        // 检查是否被删除
        if (deletedListIds.contains(remoteList.id)) {
          final deleteRecord = allDeletedItems[remoteList.id]!;
          if (deleteRecord.deletedAt.isAfter(remoteList.updatedAt)) {
            continue; // 跳过已删除的列表
          }
        }
        // 过滤已删除的待办项
        final filteredList = _filterDeletedItems(remoteList, deletedItemIds, allDeletedItems);
        mergedLists.add(filteredList.list);
        listsAdded++;
        itemsAdded += filteredList.list.items.length;
      }
    }

    // 合并 listOrder（以最新修改时间为准）
    final List<String> mergedListOrder;
    if (remote.manifest.lastModified.isAfter(local.manifest.lastModified)) {
      // 远程更新，使用远程顺序
      mergedListOrder = remote.manifest.listOrder
          .where((id) => mergedLists.any((l) => l.id == id))
          .toList();
      // 添加本地新增的（不在远程顺序中的）
      for (final list in mergedLists) {
        if (!mergedListOrder.contains(list.id)) {
          mergedListOrder.add(list.id);
        }
      }
    } else {
      // 本地更新或相同，使用本地顺序
      mergedListOrder = local.manifest.listOrder
          .where((id) => mergedLists.any((l) => l.id == id))
          .toList();
      // 添加远程新增的
      for (final list in mergedLists) {
        if (!mergedListOrder.contains(list.id)) {
          mergedListOrder.add(list.id);
        }
      }
    }

    // 构建合并后的清单
    final mergedMetas = mergedLists.map((list) => ListMeta(
      id: list.id,
      title: list.title,
      sortOrder: mergedListOrder.indexOf(list.id),
      updatedAt: list.updatedAt,
      backgroundColor: list.backgroundColor,
    )).toList();

    // 清理过期的墓碑记录（保留最近 30 天的）
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final cleanedDeletedItems = allDeletedItems.values
        .where((item) => item.deletedAt.isAfter(cutoffDate))
        .toList();

    final mergedManifest = SyncManifest(
      version: local.manifest.version,
      lists: mergedMetas,
      listOrder: mergedListOrder,
      lastModified: DateTime.now(),
      deletedItems: cleanedDeletedItems,
    );

    debugPrint('[SyncService] 合并完成: 新增$listsAdded列表, 更新$listsUpdated列表, 删除$listsDeleted列表');
    debugPrint('[SyncService] 待办项: 新增$itemsAdded, 更新$itemsUpdated, 删除$itemsDeleted');

    return _MergeResult(
      manifest: mergedManifest,
      lists: mergedLists,
      result: SyncResult(
        listsAdded: listsAdded,
        listsUpdated: listsUpdated,
        itemsAdded: itemsAdded,
        itemsUpdated: itemsUpdated,
        syncTime: DateTime.now(),
      ),
    );
  }

  /// 过滤已删除的待办项
  ({TodoList list, int itemsDeleted}) _filterDeletedItems(
    TodoList list,
    Set<String> deletedItemIds,
    Map<String, DeletedItem> deleteRecords,
  ) {
    int itemsDeleted = 0;
    final filteredItems = list.items.where((item) {
      if (deletedItemIds.contains(item.id)) {
        final deleteRecord = deleteRecords[item.id]!;
        if (deleteRecord.deletedAt.isAfter(item.updatedAt)) {
          itemsDeleted++;
          return false; // 过滤掉
        }
      }
      return true;
    }).toList();

    return (
      list: list.copyWith(items: filteredItems),
      itemsDeleted: itemsDeleted,
    );
  }

  /// 合并单个列表
  _ListMergeResult _mergeList(
    TodoList local,
    TodoList remote,
    Set<String> deletedItemIds,
    Map<String, DeletedItem> deleteRecords,
  ) {
    final mergedItems = <TodoItem>[];
    final processedItemIds = <String>{};
    int itemsAdded = 0;
    int itemsUpdated = 0;
    int itemsDeleted = 0;

    // 构建远程项目映射
    final remoteItemMap = {for (var i in remote.items) i.id: i};

    // 处理本地项目
    for (final localItem in local.items) {
      // 检查是否被删除
      if (deletedItemIds.contains(localItem.id)) {
        final deleteRecord = deleteRecords[localItem.id]!;
        if (deleteRecord.deletedAt.isAfter(localItem.updatedAt)) {
          itemsDeleted++;
          processedItemIds.add(localItem.id);
          continue; // 跳过已删除的项目
        }
      }

      final remoteItem = remoteItemMap[localItem.id];

      if (remoteItem == null) {
        // 仅本地存在
        mergedItems.add(localItem);
      } else {
        // 两边都存在，保留最新的
        if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
          mergedItems.add(remoteItem);
          // 检查是否有实际变更
          if (localItem.description != remoteItem.description ||
              localItem.isCompleted != remoteItem.isCompleted ||
              localItem.priority != remoteItem.priority) {
            itemsUpdated++;
          }
        } else {
          mergedItems.add(localItem);
        }
      }
      processedItemIds.add(localItem.id);
    }

    // 添加仅远程存在的项目（排除已删除的）
    for (final remoteItem in remote.items) {
      if (!processedItemIds.contains(remoteItem.id)) {
        // 检查是否被删除
        if (deletedItemIds.contains(remoteItem.id)) {
          final deleteRecord = deleteRecords[remoteItem.id]!;
          if (deleteRecord.deletedAt.isAfter(remoteItem.updatedAt)) {
            continue; // 跳过已删除的项目
          }
        }
        mergedItems.add(remoteItem);
        itemsAdded++;
      }
    }

    // 按 sortOrder 排序
    mergedItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // 列表属性取最新的
    final useRemoteProps = remote.updatedAt.isAfter(local.updatedAt);

    return _ListMergeResult(
      list: local.copyWith(
        items: mergedItems,
        title: useRemoteProps ? remote.title : local.title,
        backgroundColor: useRemoteProps ? remote.backgroundColor : local.backgroundColor,
        updatedAt: DateTime.now(),
      ),
      itemsAdded: itemsAdded,
      itemsUpdated: itemsUpdated,
      itemsDeleted: itemsDeleted,
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
