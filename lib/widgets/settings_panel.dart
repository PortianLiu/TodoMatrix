import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../models/settings.dart';
import '../providers/data_provider.dart';
import '../providers/sync_provider.dart';
import '../services/discovery_service.dart';
import '../services/window_service.dart';
import 'color_picker_dialog.dart';

/// 从十六进制字符串解析颜色
Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

/// 设置面板
class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(localSettingsProvider);
    final isWindows = !kIsWeb && Platform.isWindows;

    return Scaffold(
      appBar: isWindows ? _buildWindowsAppBar(context) : AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 主题设置
          _buildSectionHeader(context, '外观'),
          _buildThemeTile(context, ref, settings.themeMode),
          _buildThemeColorTile(context, ref, settings.themeColor),
          const Divider(),

          // 布局设置（列数和高度仅 Windows 显示，列表排序所有平台显示）
          _buildSectionHeader(context, '布局'),
          if (isWindows) ...[
            _buildColumnsTile(context, ref, settings.columnsPerRow),
            _buildListHeightTile(context, ref, settings.listHeight),
          ],
          _buildListOrderTile(context, ref),
          const Divider(),

          // 同步设置
          _buildSectionHeader(context, '同步'),
          _buildSyncTile(context, ref, settings.syncEnabled),
          _buildDeviceNameTile(context, ref, settings.deviceName),
          if (settings.syncEnabled) ...[
            _buildUserUidTile(context, ref, settings.userUid),
            _buildLocalIpsTile(context, ref),
            _buildDiscoveryTile(context, ref),
            _buildDeviceListTile(context, ref),
          ],
          const Divider(),

          // Windows 高级功能（仅 Windows 平台显示）
          if (!kIsWeb && Platform.isWindows) ...[
            _buildSectionHeader(context, 'Windows 功能'),
            _buildPinToDesktopTile(context, ref, settings.pinToDesktop),
            if (settings.pinToDesktop)
              _buildPinOpacityTile(context, ref, settings.pinOpacity),
            _buildEdgeHideTile(context, ref, settings.edgeHideEnabled),
            _buildCustomDataPathTile(context, ref, settings.customDataPath),
          ],
        ],
      ),
    );
  }

  /// 构建 Windows 自定义 AppBar（支持拖拽）
  PreferredSizeWidget _buildWindowsAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: GestureDetector(
        onPanStart: (_) {
          // 通知开始拖拽
          WindowService.instance.notifyDragStart();
          windowManager.startDragging();
        },
        onPanEnd: (_) {
          // 通知结束拖拽
          WindowService.instance.notifyDragEnd();
        },
        child: AppBar(
          title: const Text('设置'),
        ),
      ),
    );
  }

  /// 构建分区标题
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  /// 构建主题设置项
  Widget _buildThemeTile(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('主题'),
      subtitle: Text(_getThemeModeText(currentMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, ref, currentMode),
    );
  }

  /// 获取主题模式文本
  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  /// 显示主题选择对话框
  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, ref, ThemeMode.system, '跟随系统', currentMode),
            _buildThemeOption(context, ref, ThemeMode.light, '浅色', currentMode),
            _buildThemeOption(context, ref, ThemeMode.dark, '深色', currentMode),
          ],
        ),
      ),
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
    String label,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: mode,
      groupValue: currentMode,
      onChanged: (value) {
        if (value != null) {
          ref.read(dataProvider.notifier).setThemeMode(value);
          Navigator.of(context).pop();
        }
      },
    );
  }

  /// 构建主题色设置项
  Widget _buildThemeColorTile(BuildContext context, WidgetRef ref, String currentColor) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _hexToColor(currentColor),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
      title: const Text('主题色'),
      subtitle: Text('#$currentColor'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeColorDialog(context, ref, currentColor),
    );
  }

  /// 显示主题色选择对话框
  void _showThemeColorDialog(BuildContext context, WidgetRef ref, String currentColor) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        title: '选择主题色',
        currentColor: currentColor,
        presetColors: ThemeColors.presetColors,
        onColorSelected: (colorHex) {
          ref.read(dataProvider.notifier).setThemeColor(colorHex);
        },
      ),
    );
  }

  /// 构建列数设置项
  Widget _buildColumnsTile(BuildContext context, WidgetRef ref, int currentColumns) {
    return ListTile(
      leading: const Icon(Icons.grid_view_outlined),
      title: const Text('每行列数'),
      subtitle: Text('$currentColumns 列'),
      trailing: SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: currentColumns > 1
                  ? () => ref.read(dataProvider.notifier).setColumnsPerRow(currentColumns - 1)
                  : null,
            ),
            Text('$currentColumns', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: currentColumns < 10
                  ? () => ref.read(dataProvider.notifier).setColumnsPerRow(currentColumns + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建列表高度设置项
  Widget _buildListHeightTile(BuildContext context, WidgetRef ref, double currentHeight) {
    return ListTile(
      leading: const Icon(Icons.height_outlined),
      title: const Text('列表高度'),
      subtitle: Text('${currentHeight.toInt()} 像素'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: currentHeight,
          min: 200,
          max: 800,
          divisions: 12,
          label: '${currentHeight.toInt()}',
          onChanged: (value) {
            ref.read(dataProvider.notifier).setListHeight(value);
          },
        ),
      ),
    );
  }

  /// 构建列表排序设置项
  /// 构建列表排序设置项（内嵌可拖拽方块）
  Widget _buildListOrderTile(BuildContext context, WidgetRef ref) {
    return _ListOrderSection();
  }

  /// 构建同步开关
  Widget _buildSyncTile(BuildContext context, WidgetRef ref, bool syncEnabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.sync_outlined),
      title: const Text('启用局域网同步'),
      subtitle: Text(syncEnabled ? '已启用' : '已禁用'),
      value: syncEnabled,
      onChanged: (value) async {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(syncEnabled: value),
            );
        
        // 开启同步时，立即初始化并启动监听服务
        if (value) {
          final syncNotifier = ref.read(syncProvider.notifier);
          await syncNotifier.initialize(currentSettings.deviceName);
          await syncNotifier.startListening();
          // 启动后发起一次广播
          await syncNotifier.broadcastOnly();
        } else {
          // 关闭同步时，停止监听服务
          await ref.read(syncProvider.notifier).stopListening();
        }
      },
    );
  }

  /// 构建设备名称设置项
  Widget _buildDeviceNameTile(BuildContext context, WidgetRef ref, String deviceName) {
    return ListTile(
      leading: const Icon(Icons.devices_outlined),
      title: const Text('设备名称'),
      subtitle: Text(deviceName),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _showDeviceNameDialog(context, ref, deviceName),
    );
  }

  /// 生成唯一 UID（时间戳36进制 + 4位随机字符）
  String _generateUid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomPart = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$timestamp$randomPart';
  }

  /// 构建用户 UID 设置项
  Widget _buildUserUidTile(BuildContext context, WidgetRef ref, String userUid) {
    // 如果 UID 为空，自动生成一个
    if (userUid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newUid = _generateUid();
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(userUid: newUid),
            );
        ref.read(syncProvider.notifier).updateUserSettings(newUid, currentSettings.trustedDevices);
      });
    }

    return ListTile(
      leading: const Icon(Icons.fingerprint),
      title: const Text('设备标识 (UID)'),
      subtitle: Text(userUid.isEmpty ? '正在生成...' : userUid),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (userUid.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制 UID',
              onPressed: () => _copyToClipboard(context, userUid),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '重新生成 UID',
            onPressed: () => _showRefreshUidDialog(context, ref),
          ),
        ],
      ),
      onTap: () => _showUidInfoDialog(context, ref, userUid),
    );
  }

  /// 复制到剪贴板
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
  }

  /// 显示 UID 信息对话框
  void _showUidInfoDialog(BuildContext context, WidgetRef ref, String currentUid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备标识 (UID)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每个设备都有唯一的 UID，用于在局域网中识别设备。\n\n'
              '要与其他设备同步，需要将对方添加为"可信设备"。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('本机 UID：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentUid,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyToClipboard(context, currentUid),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示重新生成 UID 确认对话框
  void _showRefreshUidDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成 UID'),
        content: const Text(
          '重新生成 UID 后，其他设备需要重新将你添加为可信设备才能同步。\n\n确定要重新生成吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newUid = _generateUid();
              final currentSettings = ref.read(localSettingsProvider);
              ref.read(dataProvider.notifier).updateSettings(
                    currentSettings.copyWith(userUid: newUid),
                  );
              ref.read(syncProvider.notifier).updateUserSettings(newUid, currentSettings.trustedDevices);
              Navigator.of(context).pop();
            },
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }

  /// 显示设备名称编辑对话框
  void _showDeviceNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入设备名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final currentSettings = ref.read(localSettingsProvider);
                ref.read(dataProvider.notifier).updateSettings(
                      currentSettings.copyWith(deviceName: newName),
                    );
              }
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 构建本机IP展示项（不折叠，直接展示）
  Widget _buildLocalIpsTile(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<String>>(
      future: _getLocalBroadcastIps(),
      builder: (context, snapshot) {
        final ips = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: const Text('本机地址'),
              subtitle: Text(ips.isEmpty ? '获取中...' : '${ips.length} 个网络接口'),
            ),
            if (ips.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 72, right: 16, bottom: 8),
                child: Text('未检测到网络接口', style: TextStyle(color: Colors.grey)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: ips.map((ip) => InkWell(
                    onTap: () => _copyToClipboard(context, ip.split(' ').first),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ip,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  )).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 获取本机所有广播IP
  Future<List<String>> _getLocalBroadcastIps() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        // 跳过虚拟接口
        if (name.contains('loopback') || 
            name.contains('vmware') || 
            name.contains('virtualbox') ||
            name.contains('vbox') ||
            name.contains('docker')) {
          continue;
        }
        for (final addr in interface.addresses) {
          ips.add('${addr.address} (${interface.name})');
        }
      }
    } catch (e) {
      debugPrint('[Settings] 获取本机IP失败: $e');
    }
    return ips;
  }

  /// 构建设备发现项（包含已发现设备列表）
  Widget _buildDiscoveryTile(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final devices = ref.watch(discoveredDevicesProvider);
    final settings = ref.watch(localSettingsProvider);
    final trustedDevices = settings.trustedDevices;
    final isDiscovering = syncState.status == SyncStatus.broadcasting;
    
    return ExpansionTile(
      leading: Icon(
        Icons.wifi_find,
        color: isDiscovering ? Colors.blue : (devices.isNotEmpty ? Colors.green : null),
      ),
      title: const Text('设备发现'),
      subtitle: Text(isDiscovering 
          ? '正在搜索...' 
          : devices.isEmpty 
              ? '未发现设备' 
              : '发现 ${devices.length} 个设备'),
      trailing: isDiscovering
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索设备',
              onPressed: () async {
                final settings = ref.read(localSettingsProvider);
                final notifier = ref.read(syncProvider.notifier);
                await notifier.initialize(settings.deviceName);
                await notifier.broadcastOnly();
              },
            ),
      initiallyExpanded: true,
      children: [
        if (devices.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.only(left: 72, right: 16),
            dense: true,
            title: Text('未发现设备', style: TextStyle(color: Colors.grey)),
            subtitle: Text('点击搜索按钮发现附近设备'),
          )
        else
          ...devices.map((device) => _buildDiscoveredDeviceItem(context, ref, device, trustedDevices)),
      ],
    );
  }

  /// 构建已发现设备项（仅显示添加可信按钮）
  Widget _buildDiscoveredDeviceItem(BuildContext context, WidgetRef ref, DeviceInfo device, List<String> trustedDevices) {
    // 使用 userUid 判断是否为可信设备
    final isTrusted = device.userUid.isNotEmpty && trustedDevices.contains(device.userUid);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              device.deviceName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isTrusted)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('已添加', style: TextStyle(fontSize: 10, color: Colors.green)),
            ),
        ],
      ),
      subtitle: Text(
        '${device.address.address} · UID: ${device.userUid.isNotEmpty ? (device.userUid.length > 12 ? '${device.userUid.substring(0, 12)}...' : device.userUid) : '未知'}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isTrusted
          ? null
          : TextButton(
              // 使用 userUid 添加可信设备（如果没有 userUid 则不能添加）
              onPressed: device.userUid.isNotEmpty 
                  ? () => _toggleTrustedDevice(ref, device.userUid, false)
                  : null,
              child: Text(device.userUid.isEmpty ? 'UID未知' : '添加'),
            ),
    );
  }

  /// 构建设备管理项（仅可信设备列表）
  Widget _buildDeviceListTile(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(discoveredDevicesProvider);
    final settings = ref.watch(localSettingsProvider);
    final trustedDevices = settings.trustedDevices;
    final syncState = ref.watch(syncProvider);
    
    // 计算在线的可信设备数（使用 userUid 匹配）
    final onlineTrustedCount = devices.where((d) => 
        d.userUid.isNotEmpty && trustedDevices.contains(d.userUid)
    ).length;
    
    // 判断是否正在同步
    final isSyncing = syncState.status == SyncStatus.syncing || 
                      syncState.status == SyncStatus.connecting;

    return ExpansionTile(
      leading: const Icon(Icons.verified_user_outlined),
      title: const Text('可信设备'),
      subtitle: Text(_buildDeviceSubtitle(trustedDevices.length, onlineTrustedCount, syncState)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 添加按钮
          TextButton(
            onPressed: () => _showAddTrustedDeviceDialog(context, ref),
            child: const Text('添加'),
          ),
          // 立即同步按钮
          TextButton(
            onPressed: isSyncing 
                ? null 
                : () async {
                    final settings = ref.read(localSettingsProvider);
                    final notifier = ref.read(syncProvider.notifier);
                    await notifier.initialize(settings.deviceName);
                    await notifier.syncWithTrustedDevices();
                  },
            child: isSyncing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('同步'),
          ),
        ],
      ),
      initiallyExpanded: true,
      children: [
        // 同步状态提示（仅在同步中或有结果时显示）
        if (syncState.status != SyncStatus.idle && syncState.status != SyncStatus.broadcasting)
          _buildSyncStatusHint(context, syncState),
        
        if (trustedDevices.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.only(left: 72, right: 16),
            dense: true,
            title: Text('未添加可信设备', style: TextStyle(color: Colors.grey)),
            subtitle: Text('从"设备发现"中添加，或手动输入设备ID'),
          )
        else
          ...trustedDevices.map((userUid) {
            // 使用 userUid 匹配在线设备
            final onlineDevice = devices.where((d) => d.userUid == userUid).firstOrNull;
            return _buildTrustedDeviceItem(context, ref, userUid, onlineDevice);
          }),
        
        const SizedBox(height: 8),
      ],
    );
  }

  /// 构建设备副标题
  String _buildDeviceSubtitle(int trustedCount, int onlineTrustedCount, SyncState syncState) {
    if (trustedCount == 0) {
      return '未添加可信设备';
    }
    
    // 显示同步状态
    if (syncState.status == SyncStatus.syncing || syncState.status == SyncStatus.connecting) {
      return syncState.message ?? '正在同步...';
    }
    if (syncState.status == SyncStatus.completed) {
      return '同步完成';
    }
    if (syncState.status == SyncStatus.failed) {
      return '同步失败';
    }
    
    return '$onlineTrustedCount/$trustedCount 在线';
  }

  /// 构建同步状态提示
  Widget _buildSyncStatusHint(BuildContext context, SyncState syncState) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (syncState.status) {
      case SyncStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = syncState.message ?? '正在连接...';
        break;
      case SyncStatus.syncing:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = syncState.message ?? '正在同步...';
        break;
      case SyncStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '同步完成';
        break;
      case SyncStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = syncState.message ?? '同步失败';
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 72, right: 16, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(fontSize: 12, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建可信设备项（平级展示）
  /// userUid: 可信设备的 UID
  Widget _buildTrustedDeviceItem(BuildContext context, WidgetRef ref, String userUid, DeviceInfo? onlineDevice) {
    final isOnline = onlineDevice != null;
    
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Icon(
        isOnline ? Icons.check_circle : Icons.circle_outlined,
        size: 20,
        color: isOnline ? Colors.green : Colors.grey,
      ),
      title: Text(
        isOnline ? onlineDevice.deviceName : 'UID: ${userUid.length > 12 ? '${userUid.substring(0, 12)}...' : userUid}',
        style: TextStyle(color: isOnline ? null : Colors.grey),
      ),
      subtitle: Text(
        isOnline 
            ? '${onlineDevice.address.address} · 在线'
            : '离线',
        style: TextStyle(fontSize: 12, color: isOnline ? null : Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOnline)
            TextButton(
              onPressed: () => ref.read(syncProvider.notifier).syncWithDevice(onlineDevice),
              child: const Text('同步'),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '移除可信设备',
            onPressed: () => _toggleTrustedDevice(ref, userUid, true),
          ),
        ],
      ),
    );
  }

  /// 显示添加可信设备对话框
  void _showAddTrustedDeviceDialog(BuildContext context, WidgetRef ref) {
    final devices = ref.read(discoveredDevicesProvider);
    final settings = ref.read(localSettingsProvider);
    final trustedDevices = settings.trustedDevices;
    
    // 过滤出未添加为可信的已发现设备
    final untrustedDevices = devices.where((d) => !trustedDevices.contains(d.deviceId)).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加可信设备'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '从已发现的设备中选择，或手动输入设备ID。\n只有可信设备之间才能同步数据。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (untrustedDevices.isNotEmpty) ...[
                const Text('已发现的设备：', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...untrustedDevices.map((device) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.deviceName),
                  subtitle: Text('ID: ${device.deviceId.substring(0, 16)}...'),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      _toggleTrustedDevice(ref, device.deviceId, false);
                      Navigator.of(context).pop();
                    },
                    child: const Text('添加'),
                  ),
                )),
                const Divider(),
              ],
              const Text('手动输入设备ID：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _ManualDeviceIdInput(
                onAdd: (deviceId) {
                  _toggleTrustedDevice(ref, deviceId, false);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  /// 切换可信设备状态
  void _toggleTrustedDevice(WidgetRef ref, String deviceId, bool currentlyTrusted) {
    final settings = ref.read(localSettingsProvider);
    final newTrustedDevices = List<String>.from(settings.trustedDevices);
    
    if (currentlyTrusted) {
      newTrustedDevices.remove(deviceId);
    } else {
      newTrustedDevices.add(deviceId);
    }
    
    ref.read(dataProvider.notifier).updateSettings(
          settings.copyWith(trustedDevices: newTrustedDevices),
        );
    ref.read(syncProvider.notifier).updateUserSettings(settings.userUid, newTrustedDevices);
  }



  /// 构建钉在桌面设置项
  Widget _buildPinToDesktopTile(BuildContext context, WidgetRef ref, bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.push_pin_outlined),
      title: const Text('钉在桌面'),
      subtitle: const Text('窗口半透明置顶，不占用任务栏位置'),
      value: enabled,
      onChanged: (value) async {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(pinToDesktop: value),
            );
        // 应用窗口设置（使用保存的透明度）
        await WindowService.instance.setPinToDesktop(value, opacity: currentSettings.pinOpacity);
      },
    );
  }

  /// 构建钉在桌面透明度设置项
  Widget _buildPinOpacityTile(BuildContext context, WidgetRef ref, double opacity) {
    return ListTile(
      leading: const Icon(Icons.opacity_outlined),
      title: const Text('窗口透明度'),
      subtitle: Text('${(opacity * 100).toInt()}%'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: opacity,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          label: '${(opacity * 100).toInt()}%',
          onChanged: (value) async {
            final currentSettings = ref.read(localSettingsProvider);
            ref.read(dataProvider.notifier).updateSettings(
                  currentSettings.copyWith(pinOpacity: value),
                );
            // 实时应用透明度
            await WindowService.instance.setPinOpacity(value);
          },
        ),
      ),
    );
  }

  /// 构建贴边隐藏设置项
  Widget _buildEdgeHideTile(BuildContext context, WidgetRef ref, bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.border_left_outlined),
      title: const Text('贴边隐藏'),
      subtitle: const Text('窗口贴边后自动隐藏，鼠标靠近时滑出'),
      value: enabled,
      onChanged: (value) async {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(edgeHideEnabled: value),
            );
        // 应用窗口设置
        await WindowService.instance.setEdgeHide(value);
      },
    );
  }

  /// 构建自定义数据路径设置项
  Widget _buildCustomDataPathTile(BuildContext context, WidgetRef ref, String? currentPath) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: const Text('数据存储路径'),
      subtitle: Text(currentPath ?? '默认路径（%APPDATA%/TodoMatrix）'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentPath != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '恢复默认',
              onPressed: () => _resetDataPath(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '选择文件夹',
            onPressed: () => _selectDataPath(context, ref),
          ),
        ],
      ),
    );
  }

  /// 选择数据路径
  Future<void> _selectDataPath(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择数据存储路径',
    );

    if (result != null) {
      // 确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更改数据路径'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('确定要将数据存储路径更改为：'),
              const SizedBox(height: 8),
              Text(
                result,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '注意：更改路径后需要重启应用才能生效。\n现有数据不会自动迁移。',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final currentSettings = ref.read(localSettingsProvider);
        ref.read(dataProvider.notifier).updateSettings(
              currentSettings.copyWith(customDataPath: result),
            );
        // 提示重启
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据路径已更改，请重启应用以生效')),
          );
        }
      }
    }
  }

  /// 重置数据路径
  Future<void> _resetDataPath(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认路径'),
        content: const Text('确定要恢复默认数据存储路径吗？\n更改后需要重启应用才能生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentSettings = ref.read(localSettingsProvider);
      ref.read(dataProvider.notifier).updateSettings(
            currentSettings.copyWith(clearCustomDataPath: true),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复默认路径，请重启应用以生效')),
        );
      }
    }
  }
}


/// 列表排序区域（内嵌可拖拽方块，即时生效）
class _ListOrderSection extends ConsumerStatefulWidget {
  const _ListOrderSection();

  @override
  ConsumerState<_ListOrderSection> createState() => _ListOrderSectionState();
}

class _ListOrderSectionState extends ConsumerState<_ListOrderSection> {
  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(sortedListsProvider);

    if (lists.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.reorder),
        title: Text('列表排序'),
        subtitle: Text('暂无列表'),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reorder,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 10),
              Text(
                '列表排序',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(width: 10),
              Text(
                '拖拽调整顺序',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ReorderableWrap(
            spacing: 8,
            runSpacing: 8,
            onReorder: (oldIndex, newIndex) {
              // 即时保存排序
              final currentOrder = lists.map((l) => l.id).toList();
              final item = currentOrder.removeAt(oldIndex);
              currentOrder.insert(newIndex, item);
              ref.read(dataProvider.notifier).updateListOrder(currentOrder);
            },
            children: lists.map((list) {
              return _buildListChip(context, list);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListChip(BuildContext context, dynamic list) {
    // 获取列表底色（适配深浅色模式）
    Color bgColor;
    if (list.backgroundColor != null && list.backgroundColor != 'ffffff') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final baseColor = _hexToColor(list.backgroundColor!);
      if (isDark) {
        // 深色模式：降低亮度
        final hsl = HSLColor.fromColor(baseColor);
        final darkHsl = hsl.withLightness((hsl.lightness * 0.3).clamp(0.15, 0.35));
        bgColor = darkHsl.toColor();
      } else {
        bgColor = baseColor;
      }
    } else {
      bgColor = Theme.of(context).cardColor;
    }

    return Container(
      key: ValueKey(list.id),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        list.title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// 可重排序的 Wrap 组件
class ReorderableWrap extends StatefulWidget {
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;
  final double spacing;
  final double runSpacing;

  const ReorderableWrap({
    super.key,
    required this.children,
    required this.onReorder,
    this.spacing = 0,
    this.runSpacing = 0,
  });

  @override
  State<ReorderableWrap> createState() => _ReorderableWrapState();
}

class _ReorderableWrapState extends State<ReorderableWrap> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        return Draggable<int>(
          data: index,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(opacity: 0.9, child: child),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) {
              widget.onReorder(details.data, index);
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: candidateData.isNotEmpty
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
                child: child,
              );
            },
          ),
        );
      }),
    );
  }
}

/// 同步状态图标（带旋转动画）
class _SyncStatusIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final bool isAnimating;

  const _SyncStatusIcon({
    required this.icon,
    this.color,
    this.isAnimating = false,
  });

  @override
  State<_SyncStatusIcon> createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends State<_SyncStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_SyncStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _controller.forward().then((_) {
        if (!widget.isAnimating) {
          _controller.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 同步图标需要水平翻转以适应旋转方向
    final needsFlip = widget.icon == Icons.sync;
    
    if (!widget.isAnimating) {
      if (needsFlip) {
        return Transform.scale(
          scaleX: -1,
          child: Icon(widget.icon, color: widget.color),
        );
      }
      return Icon(widget.icon, color: widget.color);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (needsFlip) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(-1.0, 1.0)
              ..rotateZ(-_controller.value * 2 * 3.14159), // 逆时针旋转（翻转后视觉上为顺时针）
            child: Icon(widget.icon, color: widget.color),
          );
        }
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Icon(widget.icon, color: widget.color),
        );
      },
    );
  }
}

/// 手动输入设备ID组件
class _ManualDeviceIdInput extends StatefulWidget {
  final void Function(String deviceId) onAdd;

  const _ManualDeviceIdInput({required this.onAdd});

  @override
  State<_ManualDeviceIdInput> createState() => _ManualDeviceIdInputState();
}

class _ManualDeviceIdInputState extends State<_ManualDeviceIdInput> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final deviceId = _controller.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _errorText = '请输入设备ID');
      return;
    }
    // 简单验证：至少8个字符
    if (deviceId.length < 8) {
      setState(() => _errorText = '设备ID格式不正确');
      return;
    }
    widget.onAdd(deviceId);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '粘贴设备ID',
              errorText: _errorText,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _handleAdd(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _handleAdd,
          child: const Text('添加'),
        ),
      ],
    );
  }
}
