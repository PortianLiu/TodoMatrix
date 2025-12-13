import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 可信设备请求状态
enum TrustRequestStatus {
  none,       // 无请求
  pending,    // 待确认（我发起的请求，等待对方确认）
  incoming,   // 收到请求（对方发起的请求，等待我确认）
}

/// 可信设备请求
class TrustRequest {
  final String fromUid;     // 发起方 UID
  final String fromName;    // 发起方设备名
  final String toUid;       // 接收方 UID
  final InternetAddress fromAddress;  // 发起方地址
  final DateTime timestamp; // 请求时间

  TrustRequest({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.fromAddress,
    required this.timestamp,
  });
}

/// 设备信息
class DeviceInfo {
  final String deviceId;    // 内部使用的临时ID（UUID，每次启动不同）
  final String deviceName;  // 设备名称
  final String version;     // 版本号
  final InternetAddress address;  // IP地址
  final int port;           // 同步端口
  final DateTime lastSeen;  // 最后在线时间
  final String userUid;     // 用户UID（持久化，用于可信设备识别）
  final TrustRequestStatus trustStatus;  // 可信请求状态

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.version,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.userUid = '',
    this.trustStatus = TrustRequestStatus.none,
  });

  /// 复制并修改状态
  DeviceInfo copyWith({TrustRequestStatus? trustStatus}) {
    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      version: version,
      address: address,
      port: port,
      lastSeen: lastSeen,
      userUid: userUid,
      trustStatus: trustStatus ?? this.trustStatus,
    );
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json, InternetAddress address) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      version: json['version'] as String,
      address: address,
      port: json['port'] as int? ?? DiscoveryService.syncPort,
      lastSeen: DateTime.now(),
      userUid: json['userUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'discovery',
    'deviceId': deviceId,
    'deviceName': deviceName,
    'version': version,
    'port': port,
    'userUid': userUid,
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// 使用 userUid 作为唯一标识（如果有），否则使用 deviceId
  String get uniqueId => userUid.isNotEmpty ? userUid : deviceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo && uniqueId == other.uniqueId;

  @override
  int get hashCode => uniqueId.hashCode;
}


/// 设备发现服务
/// 使用 UDP 广播在局域网内发现其他设备
class DiscoveryService {
  static const int discoveryPort = 45678;
  static const int syncPort = 45679;
  static const Duration broadcastInterval = Duration(seconds: 5);
  // 不再使用超时清理，设备只在连接失败时才移除

  final String _deviceId;
  final String _deviceName;
  final String _version;
  String _userUid;
  List<String> _trustedDevices;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;

  final Map<String, DeviceInfo> _discoveredDevices = {};
  final _devicesController = StreamController<List<DeviceInfo>>.broadcast();
  
  // 可信请求相关
  final Map<String, Timer> _pendingRequestTimers = {};  // 待确认请求的超时计时器
  final _trustRequestController = StreamController<TrustRequest>.broadcast();  // 收到的可信请求流

  /// 发现的设备列表流
  Stream<List<DeviceInfo>> get discoveredDevices => _devicesController.stream;
  
  /// 收到的可信请求流（用于显示确认弹窗）
  Stream<TrustRequest> get trustRequests => _trustRequestController.stream;

  /// 当前发现的设备列表
  List<DeviceInfo> get devices => _discoveredDevices.values.toList();

  /// 移除设备（连接失败时调用，参数为 userUid）
  void removeDevice(String userUid) {
    final device = _discoveredDevices.remove(userUid);
    if (device != null) {
      debugPrint('[Discovery] 移除设备: ${device.deviceName} (UID: $userUid)');
      _notifyDevicesChanged();
    }
  }
  
  /// 发送可信设备请求
  void sendTrustRequest(DeviceInfo targetDevice) {
    if (_socket == null || targetDevice.userUid.isEmpty) return;
    
    final message = {
      'type': 'trust_request',
      'fromUid': _userUid,
      'fromName': _deviceName,
      'toUid': targetDevice.userUid,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final data = utf8.encode(jsonEncode(message));
    _socket!.send(data, targetDevice.address, discoveryPort);
    debugPrint('[Discovery] 发送可信请求给 ${targetDevice.deviceName}');
    
    // 更新设备状态为"待确认"
    _discoveredDevices[targetDevice.uniqueId] = targetDevice.copyWith(
      trustStatus: TrustRequestStatus.pending,
    );
    _notifyDevicesChanged();
    
    // 设置15秒超时
    _pendingRequestTimers[targetDevice.userUid]?.cancel();
    _pendingRequestTimers[targetDevice.userUid] = Timer(
      const Duration(seconds: 15),
      () => _handleRequestTimeout(targetDevice.userUid),
    );
  }
  
  /// 处理请求超时
  void _handleRequestTimeout(String targetUid) {
    debugPrint('[Discovery] 可信请求超时: $targetUid');
    _pendingRequestTimers.remove(targetUid);
    
    // 恢复设备状态
    final device = _discoveredDevices[targetUid];
    if (device != null && device.trustStatus == TrustRequestStatus.pending) {
      _discoveredDevices[targetUid] = device.copyWith(
        trustStatus: TrustRequestStatus.none,
      );
      _notifyDevicesChanged();
    }
  }
  
  /// 接受可信请求
  void acceptTrustRequest(TrustRequest request) {
    if (_socket == null) return;
    
    final message = {
      'type': 'trust_accept',
      'fromUid': _userUid,
      'fromName': _deviceName,
      'toUid': request.fromUid,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final data = utf8.encode(jsonEncode(message));
    _socket!.send(data, request.fromAddress, discoveryPort);
    debugPrint('[Discovery] 接受可信请求，回复给 ${request.fromName}');
    
    // 更新设备状态
    final device = _discoveredDevices[request.fromUid];
    if (device != null) {
      _discoveredDevices[request.fromUid] = device.copyWith(
        trustStatus: TrustRequestStatus.none,
      );
      _notifyDevicesChanged();
    }
  }
  
  /// 拒绝可信请求
  void rejectTrustRequest(TrustRequest request) {
    if (_socket == null) return;
    
    final message = {
      'type': 'trust_reject',
      'fromUid': _userUid,
      'toUid': request.fromUid,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    final data = utf8.encode(jsonEncode(message));
    _socket!.send(data, request.fromAddress, discoveryPort);
    debugPrint('[Discovery] 拒绝可信请求');
    
    // 更新设备状态
    final device = _discoveredDevices[request.fromUid];
    if (device != null) {
      _discoveredDevices[request.fromUid] = device.copyWith(
        trustStatus: TrustRequestStatus.none,
      );
      _notifyDevicesChanged();
    }
  }
  
  /// 可信请求被接受的回调
  void Function(String acceptedUid)? onTrustAccepted;
  
  /// 可信请求被拒绝的回调
  void Function(String rejectedUid)? onTrustRejected;

  DiscoveryService({
    String? deviceId,
    required String deviceName,
    String version = '1.0',
    String userUid = '',
    List<String> trustedDevices = const [],
  })  : _deviceId = deviceId ?? const Uuid().v4(),
        _deviceName = deviceName,
        _version = version,
        _userUid = userUid,
        _trustedDevices = trustedDevices;

  /// 更新用户 UID 和可信设备列表
  void updateUserSettings(String userUid, List<String> trustedDevices) {
    _userUid = userUid;
    _trustedDevices = trustedDevices;
  }

  /// 启动设备发现（仅启动监听，不自动广播）
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

      // 注意：不再自动定期广播，广播仅在用户点击同步按钮时触发
      // 也不再定期清理设备，设备只在连接失败时才移除
      
      debugPrint('[Discovery] ========== 设备发现服务启动完成（仅监听模式）==========');
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
      userUid: _userUid,
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

  /// 直接回复给指定地址（避免跨子网问题）
  void _sendReplyTo(InternetAddress targetAddress) {
    if (_socket == null) return;

    final message = {
      'type': 'discovery',
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'version': _version,
      'port': syncPort,
      'userUid': _userUid,
      'timestamp': DateTime.now().toIso8601String(),
      'isReply': true,  // 标记为回复消息
    };

    final data = utf8.encode(jsonEncode(message));

    try {
      _socket!.send(data, targetAddress, discoveryPort);
      debugPrint('[Discovery] 已发送回复到 ${targetAddress.address}:$discoveryPort');
    } catch (e) {
      debugPrint('[Discovery] 发送回复失败: $e');
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
      final messageType = message['type'] as String?;

      // 根据消息类型分发处理
      switch (messageType) {
        case 'discovery':
          _handleDiscoveryMessage(message, datagram);
          break;
        case 'trust_request':
          _handleTrustRequest(message, datagram.address);
          break;
        case 'trust_accept':
          _handleTrustAccept(message);
          break;
        case 'trust_reject':
          _handleTrustReject(message);
          break;
        default:
          debugPrint('[Discovery] 未知消息类型: $messageType');
      }
    } catch (e, stackTrace) {
      debugPrint('[Discovery] 解析数据包失败: $e');
      debugPrint('[Discovery] 堆栈: $stackTrace');
    }
  }

  /// 处理设备发现消息
  void _handleDiscoveryMessage(Map<String, dynamic> message, Datagram datagram) {
    final deviceId = message['deviceId'] as String;
    final deviceName = message['deviceName'] as String?;

    // 忽略自己的广播
    if (deviceId == _deviceId) {
      debugPrint('[Discovery] 收到自己的广播，忽略');
      return;
    }

    final device = DeviceInfo.fromJson(message, datagram.address);
      
      // 使用 userUid 作为唯一标识（如果有），否则使用 deviceId
      final uniqueKey = device.uniqueId;
      
      // 忽略自己（通过 userUid 判断）
      if (device.userUid.isNotEmpty && device.userUid == _userUid) {
        debugPrint('[Discovery] 收到自己的广播（UID匹配），忽略');
        return;
      }
      
      // 发现所有设备，不做过滤（过滤在同步时进行）
    final sourceAddr = datagram.address.address;
    debugPrint('[Discovery] ★★★ 发现设备: $deviceName @ $sourceAddr ★★★');
    debugPrint('[Discovery]   对方 UID: ${device.userUid}');
    
    final isNew = !_discoveredDevices.containsKey(uniqueKey);
    
    // 保留现有的 trustStatus（如果有）
    final existingDevice = _discoveredDevices[uniqueKey];
    final newDevice = existingDevice != null 
        ? device.copyWith(trustStatus: existingDevice.trustStatus)
        : device;
    _discoveredDevices[uniqueKey] = newDevice;
    
    // 检查是否是回复消息（避免广播风暴）
    final isReply = message['isReply'] == true;
    
    if (isNew) {
      debugPrint('[Discovery] 新设备已添加到列表，当前设备数: ${_discoveredDevices.length}');
    } else {
      debugPrint('[Discovery] 已知设备，更新信息');
    }
    
    // 如果不是回复消息，则直接回复给发送方（而不是广播，避免跨子网问题）
    if (!isReply) {
      debugPrint('[Discovery] 直接回复给 $deviceName @ $sourceAddr');
      Future.delayed(const Duration(milliseconds: 100), () {
        _sendReplyTo(datagram.address);
      });
    }
    
    _notifyDevicesChanged();
  }

  /// 处理可信请求消息
  void _handleTrustRequest(Map<String, dynamic> message, InternetAddress fromAddress) {
    final fromUid = message['fromUid'] as String?;
    final fromName = message['fromName'] as String?;
    final toUid = message['toUid'] as String?;
    
    if (fromUid == null || toUid == null) return;
    
    // 检查是否是发给自己的
    if (toUid != _userUid) {
      debugPrint('[Discovery] 可信请求不是发给自己的，忽略');
      return;
    }
    
    debugPrint('[Discovery] 收到可信请求: 来自 $fromName ($fromUid)');
    
    // 更新设备状态为"收到请求"
    final device = _discoveredDevices[fromUid];
    if (device != null) {
      _discoveredDevices[fromUid] = device.copyWith(
        trustStatus: TrustRequestStatus.incoming,
      );
      _notifyDevicesChanged();
    }
    
    // 发送请求到流，让 UI 显示确认弹窗
    _trustRequestController.add(TrustRequest(
      fromUid: fromUid,
      fromName: fromName ?? '未知设备',
      toUid: toUid,
      fromAddress: fromAddress,
      timestamp: DateTime.now(),
    ));
  }

  /// 处理可信接受消息
  void _handleTrustAccept(Map<String, dynamic> message) {
    final fromUid = message['fromUid'] as String?;
    final toUid = message['toUid'] as String?;
    
    if (fromUid == null || toUid == null) return;
    
    // 检查是否是发给自己的
    if (toUid != _userUid) return;
    
    debugPrint('[Discovery] 可信请求被接受: $fromUid');
    
    // 取消超时计时器
    _pendingRequestTimers[fromUid]?.cancel();
    _pendingRequestTimers.remove(fromUid);
    
    // 更新设备状态
    final device = _discoveredDevices[fromUid];
    if (device != null) {
      _discoveredDevices[fromUid] = device.copyWith(
        trustStatus: TrustRequestStatus.none,
      );
      _notifyDevicesChanged();
    }
    
    // 通知回调
    onTrustAccepted?.call(fromUid);
  }

  /// 处理可信拒绝消息
  void _handleTrustReject(Map<String, dynamic> message) {
    final fromUid = message['fromUid'] as String?;
    final toUid = message['toUid'] as String?;
    
    if (fromUid == null || toUid == null) return;
    
    // 检查是否是发给自己的
    if (toUid != _userUid) return;
    
    debugPrint('[Discovery] 可信请求被拒绝: $fromUid');
    
    // 取消超时计时器
    _pendingRequestTimers[fromUid]?.cancel();
    _pendingRequestTimers.remove(fromUid);
    
    // 更新设备状态
    final device = _discoveredDevices[fromUid];
    if (device != null) {
      _discoveredDevices[fromUid] = device.copyWith(
        trustStatus: TrustRequestStatus.none,
      );
      _notifyDevicesChanged();
    }
    
    // 通知回调
    onTrustRejected?.call(fromUid);
  }

  /// 通知设备列表变化
  void _notifyDevicesChanged() {
    _devicesController.add(devices);
  }

  /// 销毁服务
  void dispose() {
    stopDiscovery();
    for (final timer in _pendingRequestTimers.values) {
      timer.cancel();
    }
    _pendingRequestTimers.clear();
    _devicesController.close();
    _trustRequestController.close();
  }
}
