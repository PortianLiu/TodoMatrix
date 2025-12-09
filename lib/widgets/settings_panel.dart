import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings.dart';
import '../providers/layout_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/todo_provider.dart';
import '../services/discovery_service.dart';
import '../services/window_service.dart';

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
    final settings = ref.watch(appSettingsProvider);
    final layoutSettings = ref.watch(layoutSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 主题设置
          _buildSectionHeader(context, '外观'),
          _buildThemeTile(context, ref, settings.themeMode),
          _buildThemeColorTile(context, ref, settings.themeColor),
          const Divider(),

          // 布局设置
          _buildSectionHeader(context, '布局'),
          _buildColumnsTile(context, ref, layoutSettings.columnsPerRow),
          const Divider(),

          // 同步设置
          _buildSectionHeader(context, '同步'),
          _buildSyncTile(context, ref, settings.syncEnabled),
          _buildDeviceNameTile(context, ref, settings.deviceName),
          if (settings.syncEnabled) ...[
            _buildSyncStatusTile(context, ref),
            _buildDeviceListTile(context, ref),
          ],
          const Divider(),

          // Windows 高级功能（仅 Windows 平台显示）
          if (!kIsWeb && Platform.isWindows) ...[
            _buildSectionHeader(context, 'Windows 功能'),
            _buildPinToDesktopTile(context, ref, settings.pinToDesktop),
            _buildEdgeHideTile(context, ref, settings.edgeHideEnabled),
            _buildCustomDataPathTile(context, ref, settings.customDataPath),
          ],
        ],
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
          ref.read(appDataProvider.notifier).setThemeMode(value);
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
      builder: (context) => AlertDialog(
        title: const Text('选择主题色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ThemeColors.presetColors.map((colorHex) {
            final color = _hexToColor(colorHex);
            final isSelected = currentColor == colorHex;
            return GestureDetector(
              onTap: () {
                ref.read(appDataProvider.notifier).setThemeColor(colorHex);
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
            );
          }).toList(),
        ),
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
                  ? () => ref.read(appDataProvider.notifier).setColumnsPerRow(currentColumns - 1)
                  : null,
            ),
            Text('$currentColumns', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: currentColumns < 10
                  ? () => ref.read(appDataProvider.notifier).setColumnsPerRow(currentColumns + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建同步开关
  Widget _buildSyncTile(BuildContext context, WidgetRef ref, bool syncEnabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.sync_outlined),
      title: const Text('启用局域网同步'),
      subtitle: Text(syncEnabled ? '已启用' : '已禁用'),
      value: syncEnabled,
      onChanged: (value) {
        final currentSettings = ref.read(appSettingsProvider);
        ref.read(appDataProvider.notifier).updateSettings(
              currentSettings.copyWith(syncEnabled: value),
            );
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
                final currentSettings = ref.read(appSettingsProvider);
                ref.read(appDataProvider.notifier).updateSettings(
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

  /// 构建同步状态项
  Widget _buildSyncStatusTile(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final status = syncState.status;

    String statusText;
    IconData statusIcon;
    Color? statusColor;

    switch (status) {
      case SyncStatus.idle:
        statusText = '空闲';
        statusIcon = Icons.cloud_outlined;
        break;
      case SyncStatus.discovering:
        statusText = '正在搜索设备...';
        statusIcon = Icons.search;
        statusColor = Colors.blue;
        break;
      case SyncStatus.connecting:
        statusText = syncState.message ?? '正在连接...';
        statusIcon = Icons.sync;
        statusColor = Colors.orange;
        break;
      case SyncStatus.syncing:
        statusText = syncState.message ?? '正在同步...';
        statusIcon = Icons.sync;
        statusColor = Colors.orange;
        break;
      case SyncStatus.completed:
        statusText = syncState.lastResult?.toString() ?? '同步完成';
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case SyncStatus.failed:
        statusText = syncState.message ?? '同步失败';
        statusIcon = Icons.error;
        statusColor = Colors.red;
        break;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: const Text('同步状态'),
      subtitle: Text(statusText),
      trailing: status == SyncStatus.discovering
          ? IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () => ref.read(syncProvider.notifier).stopDiscovery(),
            )
          : IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(syncProvider.notifier).startDiscovery(),
            ),
    );
  }

  /// 构建设备列表项
  Widget _buildDeviceListTile(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(discoveredDevicesProvider);

    if (devices.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.devices_other),
        title: Text('附近设备'),
        subtitle: Text('未发现设备，请确保其他设备已开启同步'),
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.devices_other),
      title: const Text('附近设备'),
      subtitle: Text('发现 ${devices.length} 个设备'),
      children: devices.map((device) => _buildDeviceItem(context, ref, device)).toList(),
    );
  }

  /// 构建单个设备项
  Widget _buildDeviceItem(BuildContext context, WidgetRef ref, DeviceInfo device) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(device.deviceName),
      subtitle: Text(device.address.address),
      trailing: FilledButton.tonal(
        onPressed: () => ref.read(syncProvider.notifier).syncWithDevice(device),
        child: const Text('同步'),
      ),
    );
  }

  /// 构建钉在桌面设置项
  Widget _buildPinToDesktopTile(BuildContext context, WidgetRef ref, bool enabled) {
    return SwitchListTile(
      secondary: const Icon(Icons.push_pin_outlined),
      title: const Text('钉在桌面'),
      subtitle: const Text('窗口固定在桌面最底层，不遮挡其他窗口'),
      value: enabled,
      onChanged: (value) async {
        final currentSettings = ref.read(appSettingsProvider);
        ref.read(appDataProvider.notifier).updateSettings(
              currentSettings.copyWith(pinToDesktop: value),
            );
        // 应用窗口设置
        await WindowService.instance.setPinToDesktop(value);
      },
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
        final currentSettings = ref.read(appSettingsProvider);
        ref.read(appDataProvider.notifier).updateSettings(
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
        final currentSettings = ref.read(appSettingsProvider);
        ref.read(appDataProvider.notifier).updateSettings(
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
      final currentSettings = ref.read(appSettingsProvider);
      ref.read(appDataProvider.notifier).updateSettings(
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
