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
    if (_socket != null) {
      debugPrint('[Discovery] 服务已在运行中');
      return;
    }

    debugPrint('[Discovery] ========== 启动设备发现服务 ==========');
    debugPrint('[Discovery] 本机设备ID: $_deviceId');
    debugPrint('[Discovery] 本机设备名: $_deviceName');

    try {
      // 打印本机网络接口信息
      await _printNetworkInterfaces();

      // 绑定 UDP 端口
      // 注意：reusePort 在 Windows/Android 上不支持，只使用 reuseAddress
      debugPrint('[Discovery] 正在绑定 UDP 端口 $discoveryPort...');
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      debugPrint('[Discovery] UDP 端口绑定成功，本地地址: ${_socket!.address.address}:${_socket!.port}');

      // 启用广播
      _socket!.broadcastEnabled = true;
      debugPrint('[Discovery] 广播已启用');

      // 监听数据
      _socket!.listen(
        _handleDatagram,
        onError: (error) {
          debugPrint('[Discovery] Socket 错误: $error');
        },
        onDone: () {
          debugPrint('[Discovery] Socket 已关闭');
        },
      );
      debugPrint('[Discovery] 开始监听 UDP 数据包...');

      // 开始定期广播
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) => broadcastPresence());

      // 开始定期清理过期设备
      _cleanupTimer = Timer.periodic(deviceTimeout, (_) => _cleanupExpiredDevices());

      // 立即广播一次
      await broadcastPresence();
      
      debugPrint('[Discovery] ========== 设备发现服务启动完成 ==========');
    } catch (e, stackTrace) {
      debugPrint('[Discovery] 设备发现服务启动失败: $e');
      debugPrint('[Discovery] 堆栈: $stackTrace');
    }
  }

  /// 打印本机网络接口信息
  Future<void> _printNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      debugPrint('[Discovery] 本机网络接口 (${interfaces.length} 个):');
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          debugPrint('[Discovery]   - ${interface.name}: ${addr.address}');
        }
      }
    } catch (e) {
      debugPrint('[Discovery] 获取网络接口失败: $e');
    }
  }

  /// 停止设备发现
  Future<void> stopDiscovery() async {
    debugPrint('[Discovery] 停止设备发现服务...');
    
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    _socket?.close();
    _socket = null;

    final deviceCount = _discoveredDevices.length;
    _discoveredDevices.clear();
    _notifyDevicesChanged();
    
    debugPrint('[Discovery] 服务已停止，清理了 $deviceCount 个设备');
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
    debugPrint('[Discovery] 收到 Socket 事件: $event');
    
    if (event != RawSocketEvent.read) {
      debugPrint('[Discovery] 非读取事件，忽略');
      return;
    }

    final datagram = _socket?.receive();
    if (datagram == null) {
      debugPrint('[Discovery] 数据报为空');
      return;
    }

    final sourceAddr = datagram.address.address;
    final sourcePort = datagram.port;
    final dataLength = datagram.data.length;
    debugPrint('[Discovery] 收到数据包: 来源=$sourceAddr:$sourcePort, 大小=$dataLength 字节');

    try {
      final rawData = utf8.decode(datagram.data);
      debugPrint('[Discovery] 原始数据: $rawData');
      
      final message = jsonDecode(rawData) as Map<String, dynamic>;

      if (message['type'] != 'discovery') {
        debugPrint('[Discovery] 非发现消息，类型: ${message['type']}');
        return;
      }

      final deviceId = message['deviceId'] as String;
      final deviceName = message['deviceName'] as String?;

      // 忽略自己的广播
      if (deviceId == _deviceId) {
        debugPrint('[Discovery] 收到自己的广播，忽略');
        return;
      }

      debugPrint('[Discovery] ★★★ 发现新设备: $deviceName ($deviceId) @ $sourceAddr ★★★');
      
      final device = DeviceInfo.fromJson(message, datagram.address);
      final isNew = !_discoveredDevices.containsKey(deviceId);
      _discoveredDevices[deviceId] = device;
      
      if (isNew) {
        debugPrint('[Discovery] 新设备已添加到列表，当前设备数: ${_discoveredDevices.length}');
      } else {
        debugPrint('[Discovery] 已知设备，更新最后在线时间');
      }
      
      _notifyDevicesChanged();
    } catch (e, stackTrace) {
      debugPrint('[Discovery] 解析数据包失败: $e');
      debugPrint('[Discovery] 堆栈: $stackTrace');
    }
  }

  /// 清理过期设备
  void _cleanupExpiredDevices() {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final entry in _discoveredDevices.entries) {
      final age = now.difference(entry.value.lastSeen);
      if (age > deviceTimeout) {
        expiredIds.add(entry.key);
        debugPrint('[Discovery] 设备超时: ${entry.value.deviceName} (${age.inSeconds}秒未响应)');
      }
    }

    if (expiredIds.isNotEmpty) {
      for (final id in expiredIds) {
        _discoveredDevices.remove(id);
      }
      _notifyDevicesChanged();
      debugPrint('[Discovery] 清理了 ${expiredIds.length} 个过期设备，剩余 ${_discoveredDevices.length} 个');
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
