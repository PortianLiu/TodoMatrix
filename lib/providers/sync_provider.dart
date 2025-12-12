import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/discovery_service.dart';
import '../services/sync_service.dart';
import 'data_provider.dart';

/// 同步状态
enum SyncStatus {
  idle,
  discovering,
  connecting,
  syncing,
  completed,
  failed,
}

/// 同步状态数据
class SyncState {
  final SyncStatus status;
  final List<DeviceInfo> devices;
  final String? message;
  final SyncResult? lastResult;

  const SyncState({
    this.status = SyncStatus.idle,
    this.devices = const [],
    this.message,
    this.lastResult,
  });

  SyncState copyWith({
    SyncStatus? status,
    List<DeviceInfo>? devices,
    String? message,
    SyncResult? lastResult,
    bool clearMessage = false,
    bool clearResult = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      message: clearMessage ? null : (message ?? this.message),
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
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

  SyncNotifier(this._ref) : super(const SyncState());

  /// 初始化同步服务
  Future<void> initialize(String deviceName) async {
    final settings = _ref.read(localSettingsProvider);

    _discoveryService = DiscoveryService(deviceName: deviceName);
    _syncService = SyncService(deviceId: settings.deviceName);

    // 设置数据回调（暂时保留，后续重构同步逻辑）
    // _syncService!.getLocalData = () => ...;
    // _syncService!.onDataUpdated = (data) => ...;

    // 监听设备发现
    _devicesSub = _discoveryService!.discoveredDevices.listen((devices) {
      state = state.copyWith(devices: devices);
    });

    // 监听同步事件
    _eventsSub = _syncService!.syncEvents.listen(_handleSyncEvent);
  }


  /// 处理同步事件
  void _handleSyncEvent(SyncEvent event) {
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

  /// 开始设备发现
  Future<void> startDiscovery() async {
    if (_discoveryService == null) return;

    state = state.copyWith(status: SyncStatus.discovering);
    await _discoveryService!.startDiscovery();
    await _syncService?.startServer();
  }

  /// 停止设备发现
  Future<void> stopDiscovery() async {
    await _discoveryService?.stopDiscovery();
    await _syncService?.stopServer();
    state = state.copyWith(status: SyncStatus.idle, devices: []);
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
