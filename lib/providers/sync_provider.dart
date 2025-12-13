import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/discovery_service.dart';
import '../services/sync_service.dart';
import 'data_provider.dart';

/// 同步状态
enum SyncStatus {
  idle,        // 空闲，监听中
  broadcasting, // 正在广播（按钮旋转）
  connecting,  // 正在连接
  syncing,     // 正在同步
  completed,   // 同步完成
  failed,      // 同步失败
}

/// 同步状态数据
class SyncState {
  final SyncStatus status;
  final List<DeviceInfo> devices;
  final String? message;
  final SyncResult? lastResult;
  final bool isListening; // 是否正在监听

  const SyncState({
    this.status = SyncStatus.idle,
    this.devices = const [],
    this.message,
    this.lastResult,
    this.isListening = false,
  });

  SyncState copyWith({
    SyncStatus? status,
    List<DeviceInfo>? devices,
    String? message,
    SyncResult? lastResult,
    bool? isListening,
    bool clearMessage = false,
    bool clearResult = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      message: clearMessage ? null : (message ?? this.message),
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      isListening: isListening ?? this.isListening,
    );
  }
}

/// 同步状态管理器
class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  DiscoveryService? _discoveryService;
  SyncService? _syncService;
  StreamSubscription? _devicesSub;
  StreamSubscription? _eventsSub;
  Timer? _broadcastAnimationTimer;

  SyncNotifier(this._ref) : super(const SyncState());

  /// 初始化同步服务并开始监听
  Future<void> initialize(String deviceName) async {
    if (_discoveryService != null) {
      debugPrint('[SyncProvider] 服务已初始化');
      return;
    }

    debugPrint('[SyncProvider] 初始化同步服务，设备名: $deviceName');
    
    final settings = _ref.read(localSettingsProvider);
    _discoveryService = DiscoveryService(deviceName: deviceName);
    _syncService = SyncService(deviceId: settings.deviceName);

    // 设置同步回调
    _setupSyncCallbacks();

    // 监听设备发现
    _devicesSub = _discoveryService!.discoveredDevices.listen((devices) {
      debugPrint('[SyncProvider] 设备列表更新: ${devices.length} 个设备');
      state = state.copyWith(devices: devices);
      
      // 发现新设备时自动同步（如果不在同步中）
      if (devices.isNotEmpty && 
          state.status != SyncStatus.syncing && 
          state.status != SyncStatus.connecting) {
        _autoSyncWithDevices(devices);
      }
    });

    // 监听同步事件
    _eventsSub = _syncService!.syncEvents.listen(_handleSyncEvent);
  }

  /// 设置同步服务的回调
  void _setupSyncCallbacks() {
    if (_syncService == null) return;

    // 获取本地数据的回调
    _syncService!.getLocalSyncData = () {
      final dataState = _ref.read(dataProvider);
      final settings = _ref.read(localSettingsProvider);
      
      return SyncDataPacket(
        deviceId: settings.deviceName,
        manifest: dataState.manifest,
        lists: dataState.sortedLists,
      );
    };

    // 数据更新回调
    _syncService!.onDataUpdated = (manifest, lists) {
      debugPrint('[SyncProvider] 收到合并后的数据，更新本地状态');
      _ref.read(dataProvider.notifier).applySyncedData(manifest, lists);
    };
  }

  /// 开始监听（应用启动时调用）
  Future<void> startListening() async {
    if (_discoveryService == null) {
      debugPrint('[SyncProvider] 服务未初始化，无法开始监听');
      return;
    }
    
    if (state.isListening) {
      debugPrint('[SyncProvider] 已在监听中');
      return;
    }

    debugPrint('[SyncProvider] 开始监听设备广播...');
    await _discoveryService!.startDiscovery();
    await _syncService?.startServer();
    state = state.copyWith(isListening: true);
  }

  /// 停止监听
  Future<void> stopListening() async {
    debugPrint('[SyncProvider] 停止监听');
    await _discoveryService?.stopDiscovery();
    await _syncService?.stopServer();
    state = state.copyWith(isListening: false, devices: []);
  }

  /// 发起一次广播并尝试同步
  Future<void> broadcastAndSync() async {
    if (_discoveryService == null) {
      debugPrint('[SyncProvider] 服务未初始化');
      return;
    }

    // 如果正在同步，忽略
    if (state.status == SyncStatus.syncing || 
        state.status == SyncStatus.connecting) {
      debugPrint('[SyncProvider] 正在同步中，忽略广播请求');
      return;
    }

    debugPrint('[SyncProvider] 发起广播...');
    
    // 设置广播状态（触发按钮旋转动画）
    state = state.copyWith(status: SyncStatus.broadcasting);
    
    // 确保监听已启动
    if (!state.isListening) {
      await startListening();
    }
    
    // 发送广播
    await _discoveryService!.broadcastPresence();
    
    // 1秒后结束广播动画
    _broadcastAnimationTimer?.cancel();
    _broadcastAnimationTimer = Timer(const Duration(milliseconds: 1000), () {
      if (state.status == SyncStatus.broadcasting) {
        state = state.copyWith(status: SyncStatus.idle);
        
        // 如果有设备，尝试同步
        if (state.devices.isNotEmpty) {
          _autoSyncWithDevices(state.devices);
        }
      }
    });
  }

  /// 自动与发现的设备同步
  Future<void> _autoSyncWithDevices(List<DeviceInfo> devices) async {
    if (devices.isEmpty) return;
    
    debugPrint('[SyncProvider] 自动同步，设备数: ${devices.length}');
    
    // 与所有设备同步（按顺序）
    for (final device in devices) {
      debugPrint('[SyncProvider] 同步设备: ${device.deviceName} @ ${device.address.address}');
      await syncWithDevice(device);
    }
  }

  /// 处理同步事件
  void _handleSyncEvent(SyncEvent event) {
    debugPrint('[SyncProvider] 同步事件: ${event.type}, 消息: ${event.message}');
    
    switch (event.type) {
      case SyncEventType.connecting:
        state = state.copyWith(
          status: SyncStatus.connecting,
          message: event.message,
        );
        break;
      case SyncEventType.connected:
        state = state.copyWith(
          status: SyncStatus.syncing,
          message: event.message,
        );
        break;
      case SyncEventType.exchangingData:
        state = state.copyWith(message: event.message);
        break;
      case SyncEventType.conflictDetected:
        state = state.copyWith(message: '检测到 ${event.conflicts?.length ?? 0} 个冲突');
        break;
      case SyncEventType.completed:
        state = state.copyWith(
          status: SyncStatus.completed,
          message: '同步完成',
          lastResult: event.result,
        );
        // 3 秒后恢复空闲状态
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == SyncStatus.completed) {
            state = state.copyWith(status: SyncStatus.idle, clearMessage: true);
          }
        });
        break;
      case SyncEventType.failed:
        state = state.copyWith(
          status: SyncStatus.failed,
          message: event.message,
        );
        // 3 秒后恢复空闲状态
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == SyncStatus.failed) {
            state = state.copyWith(status: SyncStatus.idle, clearMessage: true);
          }
        });
        break;
    }
  }

  /// 与指定设备同步
  Future<void> syncWithDevice(DeviceInfo device) async {
    if (_syncService == null) return;
    await _syncService!.startSync(device);
  }

  /// 停止同步
  Future<void> stopSync() async {
    await _syncService?.stopSync();
    state = state.copyWith(status: SyncStatus.idle);
  }

  @override
  void dispose() {
    _broadcastAnimationTimer?.cancel();
    _devicesSub?.cancel();
    _eventsSub?.cancel();
    _discoveryService?.dispose();
    _syncService?.dispose();
    super.dispose();
  }
}

/// 同步状态 Provider
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

/// 发现的设备列表 Provider
final discoveredDevicesProvider = Provider<List<DeviceInfo>>((ref) {
  return ref.watch(syncProvider).devices;
});

/// 同步状态 Provider
final syncStatusProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncProvider).status;
});
