import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 设备信息
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String version;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.version,
    required this.address,
    required this.port,
    required this.lastSeen,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json, InternetAddress address) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      version: json['version'] as String,
      address: address,
      port: json['port'] as int? ?? DiscoveryService.syncPort,
      lastSeen: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'discovery',
    'deviceId': deviceId,
    'deviceName': deviceName,
    'version': version,
    'port': port,
    'timestamp': DateTime.now().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}


/// 设备发现服务
/// 使用 UDP 广播在局域网内发现其他设备
class DiscoveryService {
  static const int discoveryPort = 45678;
  static const int syncPort = 45679;
  static const Duration broadcastInterval = Duration(seconds: 5);
  static const Duration deviceTimeout = Duration(seconds: 15);

  final String _deviceId;
  final String _deviceName;
  final String _version;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;

  final Map<String, DeviceInfo> _discoveredDevices = {};
  final _devicesController = StreamController<List<DeviceInfo>>.broadcast();

  /// 发现的设备列表流
  Stream<List<DeviceInfo>> get discoveredDevices => _devicesController.stream;

  /// 当前发现的设备列表
  List<DeviceInfo> get devices => _discoveredDevices.values.toList();

  DiscoveryService({
    String? deviceId,
    required String deviceName,
    String version = '1.0',
  })  : _deviceId = deviceId ?? const Uuid().v4(),
        _deviceName = deviceName,
        _version = version;

  /// 启动设备发现
  Future<void> startDiscovery() async {
    if (_socket != null) return;

    try {
      // 绑定 UDP 端口
      // 注意：reusePort 在 Windows/Android 上不支持，只使用 reuseAddress
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );

      // 启用广播
      _socket!.broadcastEnabled = true;

      // 监听数据
      _socket!.listen(_handleDatagram);

      // 开始定期广播
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) => broadcastPresence());

      // 开始定期清理过期设备
      _cleanupTimer = Timer.periodic(deviceTimeout, (_) => _cleanupExpiredDevices());

      // 立即广播一次
      await broadcastPresence();
      
      debugPrint('[Discovery] 设备发现服务已启动，端口: $discoveryPort');
    } catch (e) {
      debugPrint('[Discovery] 设备发现服务启动失败: $e');
    }
  }

  /// 停止设备发现
  Future<void> stopDiscovery() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _socket?.close();
    _socket = null;

    _discoveredDevices.clear();
    _notifyDevicesChanged();
  }

  /// 广播自身存在
  /// 向所有网络接口的广播地址发送消息
  Future<void> broadcastPresence() async {
    if (_socket == null) return;

    final message = DeviceInfo(
      deviceId: _deviceId,
      deviceName: _deviceName,
      version: _version,
      address: InternetAddress.anyIPv4,
      port: syncPort,
      lastSeen: DateTime.now(),
    ).toJson();

    final data = utf8.encode(jsonEncode(message));

    try {
      // 获取所有网络接口，向每个接口的广播地址发送
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      
      for (final interface in interfaces) {
        // 跳过回环接口和虚拟接口（VMware、VirtualBox 等）
        final name = interface.name.toLowerCase();
        if (name.contains('loopback') || 
            name.contains('vmware') || 
            name.contains('virtualbox') ||
            name.contains('vbox') ||
            name.contains('docker')) {
          continue;
        }
        
        for (final addr in interface.addresses) {
          // 计算广播地址（简化：假设 /24 子网）
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final broadcastAddr = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            _socket!.send(data, InternetAddress(broadcastAddr), discoveryPort);
            debugPrint('[Discovery] 广播到 $broadcastAddr (${interface.name})');
          }
        }
      }
      
      // 同时发送到通用广播地址
      _socket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
    } catch (e) {
      debugPrint('[Discovery] 广播失败: $e');
      // 回退到通用广播
      _socket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
    }
  }

  /// 处理接收到的数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final message = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;

      if (message['type'] != 'discovery') return;

      final deviceId = message['deviceId'] as String;

      // 忽略自己的广播
      if (deviceId == _deviceId) return;

      final device = DeviceInfo.fromJson(message, datagram.address);
      _discoveredDevices[deviceId] = device;
      _notifyDevicesChanged();
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// 清理过期设备
  void _cleanupExpiredDevices() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _discoveredDevices.entries) {
      if (now.difference(entry.value.lastSeen) > deviceTimeout) {
        expiredIds.add(entry.key);
      }
    }

    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _discoveredDevices.remove(id);
      }
      _notifyDevicesChanged();
    }
  }

  /// 通知设备列表变化
  void _notifyDevicesChanged() {
    _devicesController.add(devices);
  }

  /// 销毁服务
  void dispose() {
    stopDiscovery();
    _devicesController.close();
  }
}
